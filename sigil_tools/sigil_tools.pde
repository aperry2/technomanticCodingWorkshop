// ============================================================
// TECHNOMANTIC CODING — Sigil Toolkit
// ============================================================
//
// Optimized for M1 Max Silicon Macbook Pros.
// 
// INPUT (priority order):
//   1. Live webcam
//   2. backup_movie_h264.mp4 (in data/ folder)
//   3. my_sigil.jpg          (in data/ folder)
//
// Requires the Processing Video library (v2.2+).
//
// CONTROLS:
//   0           = Raw feed (no processing)
//   1           = Threshold
//   2           = Threshold + Newtonian hue
//   3           = Radial Symmetry
//   c           = Cycle input source (cam → video → image)
//   s           = Save frame
//   i           = Toggle invert (PARAM_INVERT)
//   TAB         = Cycle active parameter for UP/DOWN
//   UP/DOWN     = Increase / decrease current parameter
//   LEFT/RIGHT  = Radial segments ± 2 (always available)
//
// ACTIVE PARAMETER (cycle with TAB):
//   THRESHOLD    — UP/DOWN adjusts threshold level
//   HUE SPEED    — UP/DOWN adjusts color cycle speed
//   SATURATION   — UP/DOWN adjusts color saturation
//   COLOR LOCK   — UP/DOWN cycles locked Newtonian color (-1 = off)
//   ROT SPEED    — UP/DOWN adjusts radial rotation speed
//   ZOOM         — UP/DOWN adjusts radial zoom
//
// ============================================================

import processing.video.*;


// ============================================================
//  WORKSHOP PARAMETERS
// ============================================================
// All adjustable live via keyboard. TAB to select which
// parameter UP/DOWN controls. Current selection shown in HUD.

// -- THRESHOLD --
float   PARAM_THRESHOLD      = 0.7;
boolean PARAM_INVERT         = true;

// -- NEWTONIAN COLORIZER --
float   PARAM_HUE_SPEED      = 0.02;
float   PARAM_SATURATION     = 80;
int     PARAM_COLOR_LOCK     = -1;   // -1 = cycle, 0–6 = lock

// -- RADIAL SYMMETRY --
int     PARAM_SEGMENTS       = 12;
float   PARAM_ROTATION_SPEED = 0.01;
float   PARAM_RADIAL_ZOOM    = 1.0;


// ============================================================
//  PARAMETER EDITOR STATE
// ============================================================

String[] paramNames = {
  "THRESHOLD", "HUE SPEED", "SATURATION",
  "COLOR LOCK", "ROT SPEED", "ZOOM"
};
int activeParam = 0;  // index into paramNames


// ============================================================
//  INTERNAL STATE
// ============================================================

// --- Newtonian spectrum ---
static final float[]  NEWTON_HUES  = { 0, 30, 55, 120, 210, 260, 290 };
static final String[] NEWTON_NAMES = { "Red", "Orange", "Yellow", "Green", "Blue", "Indigo", "Violet" };
static final String[] NEWTON_NOTES = { "D", "E", "F", "G", "A", "B", "C" };

// --- Input sources ---
Capture cam;
Movie   video;
PImage  fallbackImage;

boolean camAvailable   = false;
boolean camReady       = false;
boolean videoAvailable = false;
boolean videoReady     = false;

String activeSource = "";
PGraphics captureBuffer;

// --- Transform state ---
int   currentMode    = 0;
float thresholdLevel;
float huePhase       = 0;
int   currentZone    = 0;
int   radialSegments;
float radialRotation = 0;


void setup() {
  size(640, 480, P2D);
  textSize(11);
  textAlign(LEFT, TOP);

  thresholdLevel = PARAM_THRESHOLD;
  radialSegments = PARAM_SEGMENTS;

  captureBuffer = createGraphics(width, height, P2D);

  // --- 1. Try webcam ---
  try {
    String[] cameras = Capture.list();
    if (cameras != null && cameras.length > 0) {
      println("[SIGIL] Cameras found: " + cameras.length);
      for (String c : cameras) println("  " + c);
      cam = new Capture(this, width, height);
      cam.start();
      camAvailable = true;
      activeSource = "cam";
      println("[SIGIL] Webcam started.");
    } else {
      println("[SIGIL] No cameras found.");
    }
  } catch (Exception e) {
    println("[SIGIL] Webcam init failed: " + e.getMessage());
    try {
      cam = new Capture(this, width, height,
        "pipeline:avfvideosrc device-index=0 ! video/x-raw, width="
        + width + ", height=" + height + ", framerate=30/1");
      cam.start();
      camAvailable = true;
      activeSource = "cam";
      println("[SIGIL] Webcam started (pipeline fallback).");
    } catch (Exception e2) {
      println("[SIGIL] Pipeline fallback also failed: " + e2.getMessage());
    }
  }

  // --- 2. Try video file ---
  java.io.File vf = new java.io.File(dataPath("backup_movie_h264.mp4"));
  if (vf.exists()) {
    println("[SIGIL] Found backup_movie_h264.mp4 (" + vf.length() + " bytes)");
    try {
      video = new Movie(this, "backup_movie_h264.mp4");
      video.loop();
      videoAvailable = true;
      if (activeSource.equals("")) activeSource = "video";
      println("[SIGIL] Movie object created, looping.");
    } catch (Exception e) {
      println("[SIGIL] Movie init failed: " + e.getMessage());
    }
  }

  // --- 3. Image fallback ---
  java.io.File imgf = new java.io.File(dataPath("my_sigil.jpg"));
  if (imgf.exists()) {
    fallbackImage = loadImage("my_sigil.jpg");
    if (fallbackImage != null) {
      fallbackImage.resize(width, height);
      if (activeSource.equals("")) activeSource = "image";
      println("[SIGIL] Loaded my_sigil.jpg as fallback.");
    }
  }

  if (activeSource.equals("")) {
    println("[SIGIL] ERROR: No input source available.");
    exit();
  }

  println("[SIGIL] Active source: " + activeSource);
}


// --- Video library callbacks ---

void captureEvent(Capture c) {
  c.read();
  if (!camReady) {
    println("[SIGIL] First cam frame (" + c.width + "x" + c.height + ")");
    camReady = true;
  }
}

void movieEvent(Movie m) {
  m.read();
  if (!videoReady) {
    println("[SIGIL] First video frame (" + m.width + "x" + m.height + ")");
    videoReady = true;
  }
}


// --- Frame grab ---

PImage grabFrame() {
  PImage source = null;

  if (activeSource.equals("cam") && camReady && cam.width > 0) {
    source = cam;
  } else if (activeSource.equals("video") && videoReady && video.width > 0) {
    source = video;
  } else if (activeSource.equals("image") && fallbackImage != null) {
    return fallbackImage;
  }

  if (source == null) return null;

  captureBuffer.beginDraw();
  captureBuffer.image(source, 0, 0, width, height);
  captureBuffer.endDraw();
  captureBuffer.loadPixels();
  return captureBuffer;
}


void draw() {
  background(0);

  PImage frame = grabFrame();
  if (frame == null) {
    fill(255);
    textAlign(CENTER, CENTER);
    text("waiting for " + activeSource + "…", width / 2, height / 2);
    textAlign(LEFT, TOP);
    return;
  }

  switch (currentMode) {
    case 0:  image(frame, 0, 0);           break;
    case 1:  drawThreshold(frame);          break;
    case 2:  drawThresholdNewton(frame);    break;
    case 3:  radialRotation += PARAM_ROTATION_SPEED;
             drawRadialSymmetry(frame);     break;
  }

  drawHUD();
}


// ============================================================
//  TRANSFORMS
// ============================================================

PImage applyThreshold(PImage src) {
  PImage img = src.copy();
  img.filter(GRAY);
  img.filter(THRESHOLD, thresholdLevel);
  if (PARAM_INVERT) img.filter(INVERT);
  return img;
}


void drawThreshold(PImage src) {
  image(applyThreshold(src), 0, 0);
}


void drawThresholdNewton(PImage src) {
  huePhase += PARAM_HUE_SPEED;

  int zone;
  float hue;

  if (PARAM_COLOR_LOCK >= 0 && PARAM_COLOR_LOCK <= 6) {
    zone = PARAM_COLOR_LOCK;
    hue = NEWTON_HUES[zone];
  } else {
    float continuous = (sin(huePhase) + 1.0) * 180.0;
    zone = constrain((int)(((sin(huePhase) + 1.0) * 0.5) * 7), 0, 6);
    hue = lerp(continuous, NEWTON_HUES[zone], 0.6);
  }
  currentZone = zone;

  PImage img = applyThreshold(src);

  img.loadPixels();
  colorMode(HSB, 360, 100, 100);
  for (int i = 0; i < img.pixels.length; i++) {
    if (brightness(img.pixels[i]) > 50) {
      img.pixels[i] = color(hue, PARAM_SATURATION, 100);
    } else {
      img.pixels[i] = color(0, 0, 0);
    }
  }
  img.updatePixels();
  image(img, 0, 0);
  colorMode(RGB, 255);
}


void drawRadialSymmetry(PImage src) {
  PImage img = applyThreshold(src);

  PGraphics pg = createGraphics(width, height, P2D);
  pg.beginDraw();
  pg.background(0);
  pg.imageMode(CENTER);

  float cx = width / 2.0;
  float cy = height / 2.0;
  float sector = TWO_PI / radialSegments;

  for (int i = 0; i < radialSegments; i++) {
    pg.pushMatrix();
    pg.translate(cx, cy);
    pg.rotate(radialRotation + i * sector);
    if (i % 2 == 1) pg.scale(-1, 1);

    pg.beginShape();
    pg.noStroke();
    pg.texture(img);
    float r = max(width, height) * PARAM_RADIAL_ZOOM;
    pg.vertex(0, 0, img.width / 2.0, img.height / 2.0);

    for (int s = 0; s <= 40; s++) {
      float a = map(s, 0, 40, -sector / 2.0, sector / 2.0);
      float px = cos(a) * r;
      float py = sin(a) * r;
      float tx = constrain(map(px, -cx * PARAM_RADIAL_ZOOM, cx * PARAM_RADIAL_ZOOM, 0, img.width), 0, img.width);
      float ty = constrain(map(py, -cy * PARAM_RADIAL_ZOOM, cy * PARAM_RADIAL_ZOOM, 0, img.height), 0, img.height);
      pg.vertex(px, py, tx, ty);
    }

    pg.endShape(CLOSE);
    pg.popMatrix();
  }

  pg.endDraw();
  image(pg, 0, 0);
}


// ============================================================
//  HUD
// ============================================================

void drawHUD() {
  String[] names = { "0: RAW FEED", "1: THRESHOLD",
                     "2: THRESHOLD + NEWTON", "3: RADIAL SYMMETRY" };

  fill(0, 180);
  noStroke();
  rect(0, 0, width, 62);

  fill(255);
  textSize(12);

  // Line 1: mode + source
  text(names[currentMode] + "  [" + activeSource + "]", 10, 8);

  // Line 2: key parameter readouts
  String info = "thresh:" + nf(thresholdLevel, 1, 2);
  if (currentMode == 2) {
    info += "  hueSpd:" + nf(PARAM_HUE_SPEED, 1, 3)
         +  "  sat:" + nf(PARAM_SATURATION, 1, 0);
    if (PARAM_COLOR_LOCK >= 0) {
      info += "  lock:" + NEWTON_NAMES[PARAM_COLOR_LOCK];
    }
  }
  if (currentMode == 3) {
    info += "  seg:" + radialSegments
         +  "  rot:" + nf(PARAM_ROTATION_SPEED, 1, 3)
         +  "  zoom:" + nf(PARAM_RADIAL_ZOOM, 1, 2);
  }
  info += "  inv:" + (PARAM_INVERT ? "Y" : "N");
  text(info, 10, 26);

  // Line 3: active parameter indicator (green)
  fill(180, 255, 180);
  text("[TAB] edit: " + paramNames[activeParam] + "  " + getActiveParamValue()
    + "    [c]source [s]save [i]invert", 10, 44);

  // Newton color swatch
  if (currentMode == 2) {
    colorMode(HSB, 360, 100, 100);
    fill(color(NEWTON_HUES[currentZone], 80, 100));
    colorMode(RGB, 255);
    noStroke();
    rect(width - 90, 10, 80, 40, 6);
    fill(0);
    textAlign(CENTER, CENTER);
    text(NEWTON_NAMES[currentZone] + " / " + NEWTON_NOTES[currentZone],
         width - 50, 30);
    textAlign(LEFT, TOP);
  }
}

String getActiveParamValue() {
  switch (activeParam) {
    case 0: return nf(thresholdLevel, 1, 2);
    case 1: return nf(PARAM_HUE_SPEED, 1, 3);
    case 2: return nf(PARAM_SATURATION, 1, 0);
    case 3: return PARAM_COLOR_LOCK == -1 ? "CYCLE" : NEWTON_NAMES[PARAM_COLOR_LOCK];
    case 4: return nf(PARAM_ROTATION_SPEED, 1, 3);
    case 5: return nf(PARAM_RADIAL_ZOOM, 1, 2);
    default: return "";
  }
}


// ============================================================
//  SOURCE SWITCHING
// ============================================================

void cycleSource() {
  if (activeSource.equals("cam")) {
    if (videoAvailable) { activeSource = "video"; return; }
    if (fallbackImage != null) { activeSource = "image"; return; }
  } else if (activeSource.equals("video")) {
    if (fallbackImage != null) { activeSource = "image"; return; }
    if (camAvailable) { activeSource = "cam"; return; }
  } else if (activeSource.equals("image")) {
    if (camAvailable) { activeSource = "cam"; return; }
    if (videoAvailable) { activeSource = "video"; return; }
  }
  println("[SIGIL] No other sources available.");
}


// ============================================================
//  INPUT
// ============================================================

void keyPressed() {
  // Mode selection
  if (key == '0') currentMode = 0;
  if (key == '1') currentMode = 1;
  if (key == '2') currentMode = 2;
  if (key == '3') currentMode = 3;

  // Source cycling
  if (key == 'c' || key == 'C') {
    cycleSource();
    println("[SIGIL] Switched to: " + activeSource);
  }

  // Save
  if (key == 's' || key == 'S') {
    saveFrame("sigil_mode" + currentMode + "_" + frameCount + ".png");
    println("Saved frame.");
  }

  // Invert toggle
  if (key == 'i' || key == 'I') {
    PARAM_INVERT = !PARAM_INVERT;
    println("[SIGIL] Invert: " + PARAM_INVERT);
  }

  // TAB cycles active parameter
  if (key == TAB) {
    activeParam = (activeParam + 1) % paramNames.length;
    println("[SIGIL] Active param: " + paramNames[activeParam]);
  }

  // LEFT/RIGHT always controls radial segments
  if (keyCode == RIGHT) radialSegments = min(radialSegments + 2, 24);
  if (keyCode == LEFT)  radialSegments = max(radialSegments - 2, 4);

  // UP/DOWN controls whichever parameter is active
  if (keyCode == UP || keyCode == DOWN) {
    float dir = (keyCode == UP) ? 1 : -1;
    switch (activeParam) {
      case 0:  // THRESHOLD
        thresholdLevel = constrain(thresholdLevel + dir * 0.05, 0, 1);
        break;
      case 1:  // HUE SPEED
        PARAM_HUE_SPEED = constrain(PARAM_HUE_SPEED + dir * 0.005, 0.001, 0.2);
        break;
      case 2:  // SATURATION
        PARAM_SATURATION = constrain(PARAM_SATURATION + dir * 5, 0, 100);
        break;
      case 3:  // COLOR LOCK
        PARAM_COLOR_LOCK = constrain(PARAM_COLOR_LOCK + (int)dir, -1, 6);
        break;
      case 4:  // ROTATION SPEED
        PARAM_ROTATION_SPEED = constrain(PARAM_ROTATION_SPEED + dir * 0.005, 0.0, 0.1);
        break;
      case 5:  // ZOOM
        PARAM_RADIAL_ZOOM = constrain(PARAM_RADIAL_ZOOM + dir * 0.1, 0.2, 4.0);
        break;
    }
  }
}
