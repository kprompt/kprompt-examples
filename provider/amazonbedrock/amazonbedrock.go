// Package amazonbedrock implements an Enterprise Deferred provider for Amazon Bedrock.
// This provider supports the compat path for deferred execution of requests.
package amazonbedrock

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"time"
)

// ProviderName is the canonical name of this provider.
const ProviderName = "amazonbedrock"

// Client is the main client struct for Amazon Bedrock provider.
type Client struct {
	// Endpoint is the base URL for the Amazon Bedrock service.
	Endpoint string

	// HTTPClient is the HTTP client used to make requests.
	HTTPClient *http.Client
}

// NewClient creates a new Amazon Bedrock client with the given endpoint.
// If httpClient is nil, http.DefaultClient will be used.
func NewClient(endpoint string, httpClient *http.Client) *Client {
	if httpClient == nil {
		httpClient = http.DefaultClient
	}
	return &Client{
		Endpoint:   endpoint,
		HTTPClient: httpClient,
	}
}

// DeferredRequest represents a deferred request to Amazon Bedrock.
type DeferredRequest struct {
	// Payload is the request payload to send.
	Payload []byte

	// Timeout is the maximum time to wait for the deferred response.
	Timeout time.Duration
}

// DeferredResponse represents the response from a deferred request.
type DeferredResponse struct {
	// StatusCode is the HTTP status code returned.
	StatusCode int

	// Body is the response body.
	Body []byte
}

// ErrTimeout indicates the deferred request timed out.
var ErrTimeout = errors.New("amazonbedrock: deferred request timed out")

// DoDeferred sends a deferred request to Amazon Bedrock and waits for the response.
// It returns ErrTimeout if the response is not received within the Timeout.
func (c *Client) DoDeferred(ctx context.Context, req DeferredRequest) (*DeferredResponse, error) {
	if c.Endpoint == "" {
		return nil, errors.New("amazonbedrock: endpoint is not set")
	}
	if req.Timeout <= 0 {
		req.Timeout = 30 * time.Second
	}

	ctx, cancel := context.WithTimeout(ctx, req.Timeout)
	defer cancel()

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.Endpoint+"/deferred", nil)
	if err != nil {
		return nil, fmt.Errorf("amazonbedrock: failed to create request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Body = http.NoBody
	if len(req.Payload) > 0 {
		httpReq.Body = nopCloser{data: req.Payload}
	}

	resp, err := c.HTTPClient.Do(httpReq)
	if err != nil {
		select {
		case <-ctx.Done():
			return nil, ErrTimeout
		default:
			return nil, fmt.Errorf("amazonbedrock: request failed: %w", err)
		}
	}
	defer resp.Body.Close()

	body := make([]byte, resp.ContentLength)
	n, err := resp.Body.Read(body)
	if err != nil && err.Error() != "EOF" {
		return nil, fmt.Errorf("amazonbedrock: failed to read response body: %w", err)
	}
	body = body[:n]

	return &DeferredResponse{
		StatusCode: resp.StatusCode,
		Body:       body,
	}, nil
}

// nopCloser implements io.ReadCloser for a byte slice.
type nopCloser struct {
	data []byte
	pos  int
}

func (n *nopCloser) Read(p []byte) (int, error) {
	if n.pos >= len(n.data) {
		return 0, fmt.Errorf("EOF")
	}
	nRead := copy(p, n.data[n.pos:])
	n.pos += nRead
	return nRead, nil
}

func (n *nopCloser) Close() error {
	return nil
}
