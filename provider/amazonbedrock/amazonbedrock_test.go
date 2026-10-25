package amazonbedrock

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestDoDeferred_Success(t *testing.T) {
	// Setup a test server that returns a fixed response.
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/deferred" {
			t.Errorf("unexpected path: %s", r.URL.Path)
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"result":"ok"}`))
	}))
	defer ts.Close()

	client := NewClient(ts.URL, nil)
	resp, err := client.DoDeferred(context.Background(), DeferredRequest{
		Payload: []byte(`{"input":"test"}`),
		Timeout: 5 * time.Second,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected status 200, got %d", resp.StatusCode)
	}
	if string(resp.Body) != `{"result":"ok"}` {
		t.Errorf("unexpected body: %s", string(resp.Body))
	}
}

func TestDoDeferred_Timeout(t *testing.T) {
	// Setup a test server that delays response beyond timeout.
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(200 * time.Millisecond)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"result":"late"}`))
	}))
	defer ts.Close()

	client := NewClient(ts.URL, nil)
	_, err := client.DoDeferred(context.Background(), DeferredRequest{
		Payload: []byte(`{"input":"test"}`),
		Timeout: 50 * time.Millisecond,
	})
	if err == nil {
		t.Fatal("expected timeout error, got nil")
	}
	if err != ErrTimeout {
		t.Fatalf("expected ErrTimeout, got %v", err)
	}
}

func TestDoDeferred_NoEndpoint(t *testing.T) {
	client := NewClient("", nil)
	_, err := client.DoDeferred(context.Background(), DeferredRequest{
		Payload: []byte(`{}`),
		Timeout: 1 * time.Second,
	})
	if err == nil {
		t.Fatal("expected error for missing endpoint, got nil")
	}
}
