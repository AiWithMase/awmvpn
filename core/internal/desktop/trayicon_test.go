package desktop

import (
	"bytes"
	"image/png"
	"testing"
)

// Every tray state has its icon in both formats: a 32 px PNG of the mark
// (the middle opaque, the corners transparent), and an ICO.
func TestTrayIcons(t *testing.T) {
	for _, name := range []string{iconRunning, iconRunningAsleep, iconSet, iconSetAsleep, iconWaiting, iconError, iconOff} {
		data, err := trayFiles.ReadFile("tray/" + name + ".png")
		if err != nil {
			t.Fatal(err)
		}
		img, err := png.Decode(bytes.NewReader(data))
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		if b := img.Bounds(); b.Dx() != 32 || b.Dy() != 32 {
			t.Fatalf("%s: size %v", name, b)
		}
		for _, p := range [][2]int{{0, 0}, {31, 0}, {0, 31}, {31, 31}} {
			if _, _, _, a := img.At(p[0], p[1]).RGBA(); a != 0 {
				t.Fatalf("%s: the corner %v should be transparent", name, p)
			}
		}
		if _, _, _, a := img.At(16, 16).RGBA(); a == 0 {
			t.Fatalf("%s: the middle should be the mark", name)
		}
		ico, err := trayFiles.ReadFile("tray/" + name + ".ico")
		if err != nil || !bytes.Equal(ico[:4], []byte{0, 0, 1, 0}) {
			t.Fatalf("%s: not an ICO file: %v", name, err)
		}
		if len(trayIcon(name)) == 0 {
			t.Fatalf("%s: no icon for this system", name)
		}
	}
}
