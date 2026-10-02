package main

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/metacubex/mihomo/common/batch"
	C "github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/tunnel"
)

const hubTestTimeout = 2 * time.Second

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
		case <-ctx.Done():
			t.Fatal("timed out waiting for delay result")
		}
	}

	if got := len(mBatch.Result()); got != 1 {
		t.Fatalf("expected one retained batch result, got %d", got)
	}
}
