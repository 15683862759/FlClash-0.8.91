package main

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/common/batch"
	C "github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/tunnel"
)

const hubTestTimeout = 2 * time.Second

type staticProxyProvider struct {
	cp.ProxyProvider
	proxies []C.Proxy
	version uint32
}

func (p *staticProxyProvider) Proxies() []C.Proxy {
	return p.proxies
}

func (p *staticProxyProvider) Version() uint32 {
	return p.version
}

func TestProxyByNameUsesProviderWithoutAllocation(t *testing.T) {
	builtinProxy := adapter.NewProxy(outbound.NewDirect())
	providerProxy := adapter.NewProxy(
		outbound.NewDirectWithOption(outbound.DirectOption{Name: "provider-node"}),
	)
	originalProxies := tunnel.Proxies()
	originalProviders := tunnel.Providers()
	t.Cleanup(func() {
		tunnel.UpdateProxies(originalProxies, originalProviders)
	})

	tunnel.UpdateProxies(
		map[string]C.Proxy{"DIRECT": builtinProxy},
		map[string]cp.ProxyProvider{
			"provider": &staticProxyProvider{proxies: []C.Proxy{providerProxy}},
		},
	)

	if got := proxyByName("provider-node"); got != providerProxy {
		t.Fatalf("expected provider proxy, got %#v", got)
	}
	if got := proxyByName("DIRECT"); got != builtinProxy {
		t.Fatalf("expected built-in proxy, got %#v", got)
	}
	if got := proxyByName("missing"); got != nil {
		t.Fatalf("expected missing proxy to be nil, got %#v", got)
	}

	if allocs := testing.AllocsPerRun(100, func() {
		_ = proxyByName("provider-node")
	}); allocs != 0 {
		t.Fatalf("expected proxy lookup to allocate nothing, got %.0f allocations", allocs)
	}
}

func TestProxyByNameRefreshesWhenProxiesChange(t *testing.T) {
	oldProxy := adapter.NewProxy(
		outbound.NewDirectWithOption(outbound.DirectOption{Name: "node"}),
	)
	newProxy := adapter.NewProxy(
		outbound.NewDirectWithOption(outbound.DirectOption{Name: "node"}),
	)
	newBuiltinProxy := adapter.NewProxy(outbound.NewDirect())
	provider := &staticProxyProvider{
		proxies: []C.Proxy{oldProxy},
		version: 1,
	}
	originalProxies := tunnel.Proxies()
	originalProviders := tunnel.Providers()
	t.Cleanup(func() {
		tunnel.UpdateProxies(originalProxies, originalProviders)
	})

	tunnel.UpdateProxies(
		map[string]C.Proxy{"DIRECT": adapter.NewProxy(outbound.NewDirect())},
		map[string]cp.ProxyProvider{"provider": provider},
	)
	if got := proxyByName("node"); got != oldProxy {
		t.Fatalf("expected initial provider proxy, got %#v", got)
	}

	provider.proxies = []C.Proxy{newProxy}
	provider.version = 2
	if got := proxyByName("node"); got != newProxy {
		t.Fatalf("expected updated provider proxy, got %#v", got)
	}

	tunnel.UpdateProxies(
		map[string]C.Proxy{"DIRECT": newBuiltinProxy},
		map[string]cp.ProxyProvider{"provider": provider},
	)
	if got := proxyByName("DIRECT"); got != newBuiltinProxy {
		t.Fatalf("expected replaced built-in proxy, got %#v", got)
	}
}

func benchmarkProxyLookup(b *testing.B, direct bool) {
	const proxyCount = 1000
	proxies := make([]C.Proxy, proxyCount)
	for index := range proxies {
		proxies[index] = adapter.NewProxy(
			outbound.NewDirectWithOption(
				outbound.DirectOption{Name: fmt.Sprintf("node-%d", index)},
			),
		)
	}

	originalProxies := tunnel.Proxies()
	originalProviders := tunnel.Providers()
	b.Cleanup(func() {
		tunnel.UpdateProxies(originalProxies, originalProviders)
	})
	tunnel.UpdateProxies(
		map[string]C.Proxy{"DIRECT": proxies[0]},
		map[string]cp.ProxyProvider{
			"provider": &staticProxyProvider{proxies: proxies},
		},
	)

	const targetName = "node-999"
	b.ResetTimer()
	for index := 0; index < b.N; index++ {
		if direct {
			if proxyByName(targetName) == nil {
				b.Fatal("expected benchmark proxy")
			}
			continue
		}

		merged := tunnel.ProxiesWithProviders()
		if merged[targetName] == nil {
			b.Fatal("expected benchmark proxy")
		}
	}
}

func BenchmarkProxyByName(b *testing.B) {
	benchmarkProxyLookup(b, true)
}

func BenchmarkProxiesWithProvidersLookup(b *testing.B) {
	benchmarkProxyLookup(b, false)
}

func TestHandleAsyncTestDelayUsesSingleBatchResultKey(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), hubTestTimeout)
	defer cancel()

	originalBatch := mBatch
	t.Cleanup(func() {
		mBatch = originalBatch
	})
	originalProxies := tunnel.Proxies()
	originalProviders := tunnel.Providers()
	t.Cleanup(func() {
		tunnel.UpdateProxies(originalProxies, originalProviders)
	})

	mBatch, _ = batch.New[bool](
		ctx,
		batch.WithConcurrencyNum[bool](2),
	)
	tunnel.UpdateProxies(map[string]C.Proxy{}, map[string]cp.ProxyProvider{})

	requests := []string{
		`{"proxy-name":"node-a","test-url":"https://example.com/a","timeout":1}`,
		`{"proxy-name":"node-b","test-url":"https://example.com/b","timeout":1}`,
	}
	results := make(chan string, len(requests))
	for _, request := range requests {
		handleAsyncTestDelay(request, func(value string) {
			results <- value
		})
	}

	expectedUrls := map[string]string{
		"node-a": "https://example.com/a",
		"node-b": "https://example.com/b",
	}
	for range requests {
		select {
		case value := <-results:
			var delay Delay
			if err := json.Unmarshal([]byte(value), &delay); err != nil {
				t.Fatalf("unmarshal delay result: %v", err)
			}
			if delay.Value != -1 {
				t.Fatalf("expected missing proxy timeout, got %d", delay.Value)
			}
			if delay.Url != expectedUrls[delay.Name] {
				t.Fatalf(
					"expected delay result for %s to use %s, got %q",
					delay.Name,
					expectedUrls[delay.Name],
					delay.Url,
				)
			}
		case <-ctx.Done():
			t.Fatal("timed out waiting for delay result")
		}
	}

	if got := len(mBatch.Result()); got != 1 {
		t.Fatalf("expected one retained batch result, got %d", got)
	}
}
