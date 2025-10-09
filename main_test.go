package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGetColorRed(t *testing.T) {
	// Override the randomColor function to always return "red"
	origRandomColor := randomColor
	randomColor = func() string { return "red" }
	defer func() { randomColor = origRandomColor }()

	req, err := http.NewRequest("GET", "/color", http.NoBody)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(getColor)

	// This should not panic
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	expected := `""`
	if rr.Body.String() != expected {
		t.Errorf("handler returned unexpected body: got %v want %v",
			rr.Body.String(), expected)
	}
}