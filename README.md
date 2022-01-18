# Description

Live-Magic-Eye is a Swift based application for rendering Magic Eye effects (autostereograms) using UIKit, MetalKit and CoreImage Quartz Filters.

# Getting Started

## Magic-Eye Formula

```
ps = p0 * (1 - (g * (kMax - kMin)) / (kMax * (255 * (1 + kMax) - g * (kMax - kMin))))
```

### Legend:
- ps: Pixel Shift
- p0: Pattern Width
- g: Grayscale Value (0-255)
- kMin: 0.2
- kMax: 1.0

## Core Image Quartz Filter Algorithm

```
/*
A Core Image kernel routine that computes a magic eye effect. Example patterm size used here is "29".
The code looks up the source pixel in the sampler and then shifts pixel by depth pixel information.
*/

kernel vec4 kernelFunction(sampler image, sampler depth, float kMin, float kMax) {
	// destination coordinate
	vec2 dc = destCoord();
	int x = int(dc.x);
	int y = int(dc.y);
	// row calculations (two pattern sizes, always swapped)
	vec3 row[2 * 29];
	// n patterns need to be calculated to reach dest x
	int n = x / 29;
	// relative destination coordinate in pattern
	int dx = x - 29 * n;
	// iterate each pattern index repeat
	for (int j = 0; j <= n; j++) {
		if (j == 0) {
			// init first half of row from source image
			for (int i = 0; i < 29; i++) {
				row[i] = sample(image, samplerTransform(image, vec2(i, y))).rgb;
			}
		} else {
			// copy second half of row to first half of row
			for (int i = 0; i < 29; i++) {
				row[i] = row[29 + i];
			}
		}
		// init second half of row from source image at next pattern index
		for (int i = 0; i < 29; i++) {
			// get image pixel at absolute position
			row[29 + i] = sample(image, samplerTransform(image, vec2(i + (j+1) * 29, y))).rgb;
		}
		// calculate shift of magic eye effect
		for (int i = 0; i < 29; i++) {
			// get depth pixel at absolute position
			vec3 depthPixel = sample(depth, samplerTransform(depth, vec2(i + j * 29, y))).rgb;
			float g = 255 * clamp(depthPixel.r, 0.0, 1.0);
	         	// magic eye formula
			int p = int(29 * (1 - (g * (kMax - kMin)) / (kMax * (255 * (1 + kMax) - g * (kMax - kMin)))));
			row[i + p] = row[i];
		}
	}
	return vec4(row[dx], 1.0); // sample(image, samplerCoord(image));
}
```
