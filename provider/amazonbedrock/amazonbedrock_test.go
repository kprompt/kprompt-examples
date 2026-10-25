package amazonbedrock

import (
	"context"
	"testing"
)

func TestNewClient(t *testing.T) {
	c := NewClient("https://bedrock.example.com", "apikey123")
	if c.Endpoint != "https://bedrock.example.com" {
		t.Errorf("expected endpoint to be set, got %q", c.Endpoint)
	}
	if c.APIKey != "apikey123" {
		t.Errorf("expected APIKey to be set, got %q", c.APIKey)
	}
	if c.HTTPClient == nil {
		t.Error("expected HTTPClient to be non-nil")
	}
}

func TestInferValidation(t *testing.T) {
	c := NewClient("https://bedrock.example.com", "apikey123")

	_, err := c.Infer(context.Background(), nil)
	if err == nil {
		t.Error("expected error for nil request")
	}

	_, err = c.Infer(context.Background(), &InferRequest{})
	if err == nil {
		t.Error("expected error for missing model and input")
	}

	_, err = c.Infer(context.Background(), &InferRequest{Model: "model1"})
	if err == nil {
		t.Error("expected error for missing input")
	}

	_, err = c.Infer(context.Background(), &InferRequest{Input: "hello"})
	if err == nil {
		t.Error("expected error for missing model")
	}
}

func TestInferSuccess(t *testing.T) {
	c := NewClient("https://bedrock.example.com", "apikey123")

	req := &InferRequest{
		Model: "test-model",
		Input: "hello world",
	}

	resp, err := c.Infer(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	expectedPrefix := "AmazonBedrock(test-model): "
	if resp == nil || len(resp.Output) <= len(expectedPrefix) {
		t.Fatalf("unexpected response output: %v", resp)
	}
	if resp.Output != expectedPrefix+"hello world" {
		t.Errorf("unexpected output, got %q, want %q", resp.Output, expectedPrefix+"hello world")
	}
}
