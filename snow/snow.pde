
// https://www.youtube.com/watch?v=yamiiGk6aSs&feature=em-share_video_user

int particleCount = 5000;
particle[] snowflakes = new particle[particleCount];

// how many levels of wind can we have? (same as levels of snow field distances)
int maxZ = 5;
// this is used to generate wind interference to accelerate the particles as they move relative to the x,y noisemap
noisemap[] wind = new noisemap[maxZ+1];

boolean windVisible   = true;
boolean debugVisible  = true;
boolean debugOneLayer = true;
int debugOneLayerTarget = 1;

float windEffect = 0.25f;
long lastMS = 0;
int windChangeRateMS = 1500;
int visibleMap = 1;
long lastMapMS = 0;
long mapChangeRateMS = windChangeRateMS * 4;

PImage snowflake;

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

  snowflake = loadImage("snowflake1.png");

  for(int z = 1; z <= maxZ; z++) {
    wind[z] = new noisemap(width, height);
  }

  for(int i =0; i < particleCount; i++) {
    snowflakes[i] = spawn();
  }

  lastMS = millis();

//addWindArea
}

void draw() {
  
  // clear the last frame
  background(0);

  // draw the noisemap for now
  if (windVisible) {

    imageMode(CORNER);
    
    if (debugOneLayer)
      visibleMap = debugOneLayerTarget;

    image(wind[visibleMap].mappy, 0, 0);
    if (millis() - lastMapMS > mapChangeRateMS) {
      visibleMap = visibleMap + 1 <= maxZ ? visibleMap + 1 : 1;
      lastMapMS = millis();
    }

    // draw small indicators on the side
    /*
    for(int z = 1; z < maxZ; z++) {
      image(wind[z].mappy, width - (width / 10), z * (height / 10), width / 10, height / 10);
    }
    */

  }
    
  //  draw the background gradient
  
  // handle all physics and draw the snowflakes
  // for(particle snowflake : snowflakes) {
  for(int i = 0; i < particleCount; i++) {

    if (debugOneLayer && snowflakes[i].zIndex != debugOneLayerTarget)
      continue;

    float[] accel = wind[snowflakes[i].zIndex].getXY((int) snowflakes[i].x, (int) snowflakes[i].y);
    // particle.changeAccel( wind.getXY((int) snowflakes[i].x, (int) snowflakes[i].y );

    float xF = accel[0] * windEffect;
    float yF = accel[1] * windEffect;
    float zF = accel[2] * windEffect;
    
    snowflakes[i].changeAcceleration( xF, yF, zF );
    snowflakes[i].update();
    snowflakes[i].draw();
    
    if (snowflakes[i].inBounds(width, height)) {
      println("throw #" + i + " back to the top");
      snowflakes[i].backToTheTop();
    }
  }
  
  if (millis() - lastMS > windChangeRateMS) {
    for(int z = 1; z < maxZ; z++) {

      if (debugOneLayer && z != debugOneLayerTarget)
        continue;

      if (random(0,1) > .4) {
        println("ADD WIND TO " + z);
        wind[z].addWindArea();
      }
      
      if (random(0,1) > .9) {
        println("INVERT AREA " + z);
        wind[z].mappy.filter(INVERT); 
      }
    }
    lastMS = millis();
  }
  
}

particle spawn() {
  float x = random(0 - 20, width + 20);
  float y = random(0 - height, 0);
  float z = fakeRandom(); // (0, maxZ);

  float d = 30; // random(2, 10); // (float) fakeRandom();
  return new particle(x, y, z, d); 
}

class noisemap {

  PImage mappy;
  // PGraphics mappy;
  
  noisemap(int mapWidth, int mapHeight) {
    mappy = createImage(mapWidth, mapHeight, RGB);
    fillMap();
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
  
  void addWindArea() {

    int startX = (int) random(0, width);
    int startY = (int) random(0, height);
    int endX = (int) random(startX, width);
    int endY = (int) random(startY, height);

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
    
    if (x < 0 || x >= mappy.width || y < 0 || y > mappy.height) {
      return colorAtXY;
    }
    
    //mappy.loadPixels();
    //color c = mappy.pixels[y * mappy.width + x];    // get(x, y);
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
  
  float friction = 0.9;
  
  // consider "density" for like, ice vs snow to affect terminal velocity
  float terminalXYZ = 20;
  
  particle(float x, float y, float z, float d ) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.d = d;
    
    this.zIndex = (int) z; // relative to windMap needs int, fuck it
    
  }

  void backToTheTop() {
    this.x = random(0 - 20, width + 20);
    this.y = random(0 - height, 0);
  }

  boolean inBounds(int x, int y) {
    return this.y > y + d || this.x > x + d || this.x + d < 0;
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
    this.velX = terminalVelocity(this.terminalXYZ, this.velX);
    this.velY = terminalVelocity(this.terminalXYZ, this.velY);
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

    // noStroke();
    ellipseMode(RADIUS);

    float distanceMult = (maxZ - this.z) / maxZ;
    float d2 = distanceMult * d;

    fill(255);
    // ellipse(x, y, d2, d2);
    imageMode(CENTER);
    image(snowflake, x, y, d2, d2);

    if (debugVisible) {
    
      fill(0);
      stroke(255);
      line(x, y, x+ this.velX * 2, y + this.velY * 2);

    }

  }
}