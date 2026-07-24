package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGetColor_NoBody(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/color", nil)
	w := httptest.NewRecorder()

	getColor(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var color string
	if err := json.Unmarshal(w.Body.Bytes(), &color); err != nil {
		t.Errorf("Failed to parse response: %v", err)
	}

	// Should return one of the valid colors
	validColors := map[string]bool{"red": true, "orange": true, "yellow": true, "green": true, "blue": true, "purple": true}
	if !validColors[color] {
		t.Errorf("Expected a valid color, got %s", color)
	}
}

func TestGetColor_EmptyArray(t *testing.T) {
	body := []byte("[]")
	req := httptest.NewRequest(http.MethodPost, "/color", bytes.NewReader(body))
	w := httptest.NewRecorder()

	getColor(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var color string
	if err := json.Unmarshal(w.Body.Bytes(), &color); err != nil {
		t.Errorf("Failed to parse response: %v", err)
	}

	// Should return one of the valid colors
	validColors := map[string]bool{"red": true, "orange": true, "yellow": true, "green": true, "blue": true, "purple": true}
	if !validColors[color] {
		t.Errorf("Expected a valid color, got %s", color)
	}
}

func TestGetColor_MalformedJSON(t *testing.T) {
	body := []byte(`[{"color": "blue"malformed`)
	req := httptest.NewRequest(http.MethodPost, "/color", bytes.NewReader(body))
	w := httptest.NewRecorder()

	getColor(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("Expected status 500 for malformed JSON, got %d", w.Code)
	}
}

func TestGetColor_WithValidBody(t *testing.T) {
	body := []byte(`[{"color": "blue", "delayLength": 0.5}]`)
	req := httptest.NewRequest(http.MethodPost, "/color", bytes.NewReader(body))
	w := httptest.NewRecorder()

	getColor(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}
	var color string
	if err := json.Unmarshal(w.Body.Bytes(), &color); err != nil {
		t.Errorf("Failed to parse response: %v", err)
	}
	// Should return one of the valid colors
	validColors := map[string]bool{"red": true, "orange": true, "yellow": true, "green": true, "blue": true, "purple": true}
	if !validColors[color] {
		t.Errorf("Expected a valid color, got %s", color)
	}
}

func TestRandomColor(t *testing.T) {
	// Test that randomColor returns a valid color
	validColors := map[string]bool{"red": true, "orange": true, "yellow": true, "green": true, "blue": true, "purple": true}
	
	for i := 0; i < 100; i++ {
		color := randomColor()
		if !validColors[color] {
			t.Errorf("randomColor returned invalid color: %s", color)
		}
	}
}

func TestRandomColor_EmptyColors(t *testing.T) {
	originalColors := colors
	colors = []string{}
	defer func() {
		colors = originalColors
	}()

	color := randomColor()
	if color != "blue" {
		t.Errorf("Expected 'blue' when colors slice is empty, got %s", color)
	}
}

func TestPrintColor(t *testing.T) {
	testCases := []struct {
		color      string
		statusCode int
	}{
		{"red", http.StatusOK},
		{"green", http.StatusOK},
		{"blue", http.StatusInternalServerError},
		{"", http.StatusOK},
	}

	for _, tc := range testCases {
		t.Run(tc.color, func(t *testing.T) {
			w := httptest.NewRecorder()
			printColor(tc.color, w, tc.statusCode)

			if w.Code != tc.statusCode {
				t.Errorf("Expected status %d, got %d", tc.statusCode, w.Code)
			}

			expected := "\"" + tc.color + "\""
			if w.Body.String() != expected {
				t.Errorf("Expected body %s, got %s", expected, w.Body.String())
			}
		})
	}
}
