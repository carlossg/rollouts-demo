package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestGetColor(t *testing.T) {
	// This test is designed to catch the panic that was occurring.
	// The original code would panic when colorToReturn was "red",
	// because it would set it to "" and then try to access index 0.
	// By removing the faulty code block, this test should now pass.

	// Force randomColor() to return "red"
	originalColors := colors
	colors = []string{"red"}
	defer func() { colors = originalColors }()

	req, err := http.NewRequest("GET", "/color", strings.NewReader(""))
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(getColor)

	// Before the fix, this call would panic.
	handler.ServeHTTP(rr, req)

	// Check the status code is what we expect.
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	// Check the body is what we expect.
	expected := `"red"`
	if rr.Body.String() != expected {
		t.Errorf("handler returned unexpected body: got %v want %v",
			rr.Body.String(), expected)
	}
}