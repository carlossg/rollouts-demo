package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGetColorRed(t *testing.T) {
	// Backup original color and defer restore
	originalColor := color
	defer func() { color = originalColor }()
	color = "red"

	// Create a request to pass to our handler. We don't have any query parameters for now, so we'll
	// pass an empty body.
	req, err := http.NewRequest("GET", "/color", http.NoBody)
	if err != nil {
		t.Fatal(err)
	}

	// We create a ResponseRecorder (which satisfies http.ResponseWriter) to record the response.
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(getColor)

	// Our handlers satisfy http.Handler, so we can call their ServeHTTP method
	// directly and pass in our Request and ResponseRecorder.
	handler.ServeHTTP(rr, req)

	// Check the status code is what we expect.
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	// Check the response body is what we expect.
	expected := `""`
	if rr.Body.String() != expected {
		t.Errorf("handler returned unexpected body: got %v want %v",
			rr.Body.String(), expected)
	}
}

func TestGetColorEmptySlice(t *testing.T) {
	// Backup original colors and defer restore
	originalColors := colors
	defer func() { colors = originalColors }()

	// Set colors to an empty slice
	colors = []string{}

	req, err := http.NewRequest("GET", "/color", http.NoBody)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(getColor)

	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	expected := `"blue"`
	if rr.Body.String() != expected {
		t.Errorf("handler returned unexpected body: got %v want %v",
			rr.Body.String(), expected)
	}
}