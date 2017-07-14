
// @todo OSC integration
// import oscP5;
// https://www.youtube.com/watch?v=yamiiGk6aSs&feature=em-share_video_user

int particleCount = 2000;
particle[] snowflakes = new particle[particleCount];

// how many levels of wind can we have? (same as levels of snow field distances)
int maxZ = 5;
// this is used to generate wind interference to accelerate the particles as they move relative to the x,y noisemap
noisemap[] wind = new noisemap[maxZ+1];

boolean windVisible     = true;
boolean debugVisible    = true;
boolean debugOneLayer   = false;
int debugOneLayerTarget = 1;

float windEffect        = 0.25f;
long lastChangeMS       = 0;
long lastUpdateMS       = 0;
int windChangeRateMS    = 1500; // how often do new wind effects come in?
int windUpdateRateMS    = 200; // how often do we apply shifts like fading / motion
int visibleMap          = 1;
long lastMapMS          = 0;
long mapChangeRateMS    = windChangeRateMS;

// wind which sticks around and is applied to every particle in the system relative {x,y,z}
float[] ambientWind     = {0,0,0};

PImage snowflake;
PGraphics snowflakeSource;

// this is used to determine the relative population of the fields
int[] fakeWeightedDistances = {
  5,5,5,5,5,5,5,5,5,5,5,5,
  4,4,4,4,4,4,
  3,3,3,3,
  2,2,
  1
};

int fakeRandom() {
  return fakeWeightedDistances[(int) random(0, fakeWeightedDistances.length)];
}

void setup() {

  frameRate(24);
  // size(640, 480);
  fullScreen();

  //snowflake = loadImage("snowflake1.png");
  snowflake = loadImage("snowflake2.png");
  // this doesn't work, not sure why - NullPinterException FU
  /*
  snowflake = createImage(200,200, ARGB);
  snowflakeSource = createGraphics(200,200); 
  
  println(snowflakeSource);

   for(int i = 10; i > 0; i--) {
    snowflakeSource.fill(255,255,255, ((200 - i) / 200) * 255);
    snowflakeSource.ellipseMode(CENTER);
    snowflakeSource.ellipse(100, 100, i, i);
    
  }

  snowflakeSource.loadPixels();
  snowflake = snowflakeSource.get();
  */

  for(int z = 1; z <= maxZ; z++) {
    wind[z] = new noisemap(width, height, 16);
  }

  for(int i =0; i < particleCount; i++) {
    snowflakes[i] = spawn();
  }

  lastChangeMS = millis();
  lastUpdateMS = millis();

//addWindArea
}

void draw() {

  // clear the last frame
  background(0);

  // draw the noisemap for now
  if (windVisible) {

    imageMode(CORNER);

    for(int z = 1; z < maxZ; z++) {

      if (debugOneLayer && z != debugOneLayerTarget)
        continue;

      image(wind[z].mappy, 0, (z - 1) * wind[z].mappy.height);
    }

    if (millis() - lastMapMS > mapChangeRateMS) {
      visibleMap = visibleMap + 1 <= maxZ ? visibleMap + 1 : 1;
      lastMapMS = millis();
    }

  }

  //  draw the background gradient

  // handle all physics and draw the snowflakes
  // for(particle snowflake : snowflakes) {
  for(int i = 0; i < particleCount; i++) {

    if (debugOneLayer && snowflakes[i].zIndex != debugOneLayerTarget)
      continue;

    float[] accel = wind[snowflakes[i].zIndex].getXY((int) snowflakes[i].x, (int) snowflakes[i].y);
    // particle.changeAccel( wind.getXY((int) snowflakes[i].x, (int) snowflakes[i].y );

    float xF = (accel[0] + ambientWind[0]) * windEffect;
    float yF = (accel[1] + ambientWind[1]) * windEffect;
    float zF = (accel[2] + ambientWind[2]) * windEffect;

    snowflakes[i].changeAcceleration( xF, yF, zF );
    snowflakes[i].update();
    
    if (snowflakes[i].y <= 0)
      println(i + " under 0");
    
    snowflakes[i].draw();

    if (!snowflakes[i].inBoundsX(width)) {
      // println("l/r loop #" + i);
      snowflakes[i].loopX(width); // pacman style
    }

    if (snowflakes[i].inBoundsY(height)) {
      // println("throw #" + i + " back to the top");
      snowflakes[i].backToTheTop(width, height);
    }
  }

  if (millis() - lastUpdateMS > windUpdateRateMS) {
    for(int z = 1; z < maxZ; z++) {

      if (debugOneLayer && z != debugOneLayerTarget)
        continue;

      wind[z].fade();
    }
    lastUpdateMS = millis();
  }

  if (millis() - lastChangeMS > windChangeRateMS) {
    for(int z = 1; z < maxZ; z++) {

      if (debugOneLayer && z != debugOneLayerTarget)
        continue;

      if (random(0,1) > .4) {
        // println("ADD WIND TO " + z);
        wind[z].addWindArea();
      }

      if (random(0,1) > .9) {
        // println("INVERT AREA " + z);
        wind[z].mappy.filter(INVERT);
      }
    }
    lastChangeMS = millis();
  }

}

/**
 * handle routing keys to the API
 */
void keyPressed() {
  
  switch (keyCode){

    case 38: // up
    break;
    
    case 40: // down
    break;
    
    case 37: // left
    break;
    
    case 39: // right
    break;
    
    case 27: // esc ?
    break;

  }
  
}

/**
 * Factory method to get a new particle within normal parameters
 * @return particle 
 */ 
particle spawn() {
  float x = random(0 - 20, width + 20);
  float y = random(0 - height, 0);
  float z = fakeRandom(); // (0, maxZ);

  float d = 30; // random(2, 10); // (float) fakeRandom();
  return new particle(x, y, z, d);
}

class noisemap {

  PImage mappy;
  PImage fader;

  int scale = 1;

  noisemap(int mapWidth, int mapHeight, int scale) {

    this.scale = scale;

    // integer division - get xpos/ypos in our scale, eg: 1->8 1->16, whatev
    mappy = createImage(mapWidth / scale, mapHeight / scale, RGB);
    fader = createImage(mapWidth / scale, mapHeight / scale, ARGB);

    fillFader();
    fillMap();

  }

  void fillFader() {

    for(int x = 0; x < fader.width; x++) {
      for(int y = 0; y < fader.height; y++) {
        fader.set(x, y, color(128,128,128,13)); // roughly 5% opacity
      }
    }

  }

  void fillMap() {

    for(int x = 0; x < mappy.width; x++) {
      for(int y = 0; y < mappy.height; y++) {
        mappy.set(x, y, color(128,128,128)); // ,0));
      }
    }

    // add some wind!
    for(int i = 0; i < 10; i++) {
      addWindArea();
    }

  }

  void fade() {
    mappy.blend(fader, 0, 0, fader.width, fader.height, 0, 0, mappy.width, mappy.height, BLEND);
  }

  void addWindArea() {

    int startX = (int) random(0, mappy.width);
    int startY = (int) random(0, mappy.height);
    int endX = (int) random(startX, mappy.width);
    int endY = (int) random(startY, mappy.height);

    int colorR = color(random(0,255), random(0,255), 128);

    for(int x = startX; x < endX; x++) {
      for(int y = startY; y < endY; y++) {
        mappy.set(x, y, colorR);
      }
    }
  }

  float[] getXY(int x, int y) {

    float[] colorAtXY = {
      0, 0, 0
    };

    x = x / scale;
    y = y / scale;

    if (x < 0 || x >= mappy.width || y < 0 || y > mappy.height) {
      return colorAtXY;
    }

    color c = mappy.get(x, y);

    int r = (c >> 16) & 0xFF;
    int g = (c >> 8 ) & 0xFF;
    int b =  c        & 0xFF;

    colorAtXY[0] = ((float) r - 128.0f) / 128.0f;
    colorAtXY[1] = ((float) g - 128.0f) / 128.0f;
    colorAtXY[2] = ((float) b - 128.0f) / 128.0f;

    return colorAtXY;
  }

}

class particle {

  int zIndex = 1;

  float x = 0;
  float y = 0;
  float z = 0;
  float d = 2;

  float gravity = 0.5;

  float accelX = 0;
  float accelY = 0;
  float accelZ = 0;

  float velX = 0;
  float velY = 0;
  float velZ = 0;

  float friction = 0.85;

  // consider "density" for like, ice vs snow to affect terminal velocity
  float terminalXYZ = 20;

  particle(float x, float y, float z, float d ) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.d = d;

    this.zIndex = (int) z; // relative to windMap needs int, fuck it (OR getZ() which handles range and then we can deal with out of bounds and whatever ->

  }

  void backToTheTop(int w, int h) {
    this.x = random(0 - 20, w + 20);
    this.y = random(0 - h, 0);
  }

  void loopX(int w) {
    if (this.x <= 0)
      this.x = w + this.d;
    else
      this.x = -this.d;
  }

  boolean inBounds(int w, int h) {
    return this.y < h + d && this.x < w + d && this.x + d > 0;
  }

  boolean inBoundsX(int w) {
    return this.x < w + d && this.x + d > 0;
  }
  
  boolean inBoundsY(int h) {
    return this.y > h + d;
  }

  float terminalVelocity(float terminal, float current) {

    if (current == 0)
      return 0;

    if (current < 0 && current < -terminal)
        return -terminal;

    if (current > terminal)
      return terminal;

    return current;
  }

  void changeAcceleration(float x, float y, float z) {

    this.accelX += x;
    this.accelY += y;
    // this.accelZ += z;
  }

  void update() {

    // positive Y accel affected by gravity
    this.accelY += this.gravity;

    // velocity affected by acceleration
    this.velX += this.accelX;
    this.velY += this.accelY;
    // this.velZ += this.accelZ;

    // terminal velocity
    // not sure if this really helps actually - sort of sucks!
    // this.velX = terminalVelocity(this.terminalXYZ, this.velX);
    // this.velY = terminalVelocity(this.terminalXYZ, this.velY);
    // this.velZ = terminalVelocity(this.terminalXYZ, this.velZ);

    // velocity affected by friction
    this.velX *= this.friction;
    this.velY *= this.friction;
    // this.velZ *= this.friction;

    this.accelX *= this.friction;
    this.accelY *= this.friction;
    // this.accelZ *= this.friction;

    float distanceMult = (maxZ - this.z) / maxZ;

    // move!
    this.x += this.velX * distanceMult;
    this.y += this.velY * distanceMult;
    // this.z += this.velZ;

  }

  void draw() {

    
    ellipseMode(RADIUS);

    float distanceMult = (maxZ - this.z) / maxZ;
    float d2 = distanceMult * d;

    //noStroke();
    //fill(255);
    //ellipse(x, y, d2, d2);

    imageMode(CENTER);
    image(snowflake, x, y, d2, d2);

    if (debugVisible) {

      fill(0);
      stroke(255);
      line(x, y, x+ this.velX * 2, y + this.velY * 2);

    }

  }
}