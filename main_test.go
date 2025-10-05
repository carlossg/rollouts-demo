package main

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

// TestGetColorWithRedColor tests that the getColor function handles the red color without panicking
func TestGetColorWithRedColor(t *testing.T) {
	// Set COLOR environment variable to red
	oldColor := color
	color = "red"
	defer func() { color = oldColor }()

	// Create a test request with empty body (most common case)
	req := httptest.NewRequest("POST", "/color", bytes.NewReader([]byte("")))
	w := httptest.NewRecorder()

	// This should not panic
	getColor(w, req)

	// Verify the response
	if w.Code != http.StatusOK {
		t.Errorf("Expected status code %d, got %d", http.StatusOK, w.Code)
	}

	expectedBody := `"red"`
	if w.Body.String() != expectedBody {
		t.Errorf("Expected body %s, got %s", expectedBody, w.Body.String())
	}
}

// TestGetColorWithAllColors tests that all colors work without panicking
func TestGetColorWithAllColors(t *testing.T) {
	testColors := []string{"red", "orange", "yellow", "green", "blue", "purple"}

	oldColor := color
	defer func() { color = oldColor }()

	for _, testColor := range testColors {
		t.Run(testColor, func(t *testing.T) {
			color = testColor

			// Create a test request with empty body
			req := httptest.NewRequest("POST", "/color", bytes.NewReader([]byte("")))
			w := httptest.NewRecorder()

			// This should not panic
			getColor(w, req)

			// Verify the response
			if w.Code != http.StatusOK {
				t.Errorf("Expected status code %d for color %s, got %d", http.StatusOK, testColor, w.Code)
			}

			expectedBody := `"` + testColor + `"`
			if w.Body.String() != expectedBody {
				t.Errorf("Expected body %s for color %s, got %s", expectedBody, testColor, w.Body.String())
			}
		})
	}
}

// TestGetColorRandomSelection tests that random color selection works without panicking
func TestGetColorRandomSelection(t *testing.T) {
	// Clear COLOR environment variable to test random selection
	oldColor := color
	color = ""
	defer func() { color = oldColor }()

	// Make multiple requests to test random selection
	for i := 0; i < 20; i++ {
		req := httptest.NewRequest("POST", "/color", bytes.NewReader([]byte("")))
		w := httptest.NewRecorder()

		// This should not panic
		getColor(w, req)

		// Verify the response is OK
		if w.Code != http.StatusOK {
			t.Errorf("Request %d: Expected status code %d, got %d", i, http.StatusOK, w.Code)
		}

		// Verify the body contains a valid color
		body := w.Body.String()
		if len(body) < 3 {
			t.Errorf("Request %d: Body too short: %s", i, body)
		}
	}
}

// TestGetColorWithEmptyBody tests that the function handles empty request bodies
func TestGetColorWithEmptyBody(t *testing.T) {
	oldColor := color
	color = "blue"
	defer func() { color = oldColor }()

	req := httptest.NewRequest("POST", "/color", bytes.NewReader([]byte("")))
	w := httptest.NewRecorder()

	// This should not panic
	getColor(w, req)

	// Verify the response
	if w.Code != http.StatusOK {
		t.Errorf("Expected status code %d, got %d", http.StatusOK, w.Code)
	}
}

// TestRandomColor tests that randomColor always returns a valid color
func TestRandomColor(t *testing.T) {
	validColors := map[string]bool{
		"red":    true,
		"orange": true,
		"yellow": true,
		"green":  true,
		"blue":   true,
		"purple": true,
	}

	// Test randomColor multiple times
	for i := 0; i < 50; i++ {
		c := randomColor()
		if !validColors[c] {
			t.Errorf("randomColor returned invalid color: %s", c)
		}
	}
}

func TestMain(m *testing.M) {
	// Setup: ensure environment variables are set correctly for tests
	os.Setenv("COLOR", "")
	os.Setenv("LATENCY", "")
	os.Setenv("ERROR_RATE", "")

	// Run tests
	code := m.Run()

	// Cleanup (if needed)
	os.Exit(code)
}
