#include <cpctelera.h>

// A list of points 
const i16 ptList[] = {
     80,  20,        // In screen
    -50,  40,        // < XMin
    360,  60,        // > XMax
    140, -50,        // < YMin
    200, 230,        // > YMax
};

// Size of ptList is 5 points, each point has 2 coordinates (x,y), each point is saved twice in case of clamping
#define NBPOINT      (u8)( 5 )
#define NBPT16       (u8)(NBPOINT * 2)
#define NBPTDR       (u8)(NBPT16 * 2)
#define TOTALBUFFER  (u8)(NBPTDR * 2)

// Buffer for saving all drawn points on 2 screen buffer
// Inititalised to -1 to indicate that no point has been drawn yet
const i16 drawnPoint [TOTALBUFFER] = {-1};   

// Origin for rotation of points
const i16 origin [2] = { 160, 100 };

// Fixed points for drawing lines
const i16 ptFixe1 [2] = { 140, 100 };
const i16 ptFixe2 [2] = { 220, 150 };

// A 128 entry sin table from -64 to 64 (to keep it a i8 size)
const i8 sintable[128] =
{
      0,   3,   6,   9,  12,  16,  19,  22,  24,  27,  30,  33,  36,  38,  41,  43, 
     45,  47,  49,  51,  53,  55,  56,  58,  59,  60,  61,  62,  63,  63,  64,  64, 
     64,  64,  64,  63,  63,  62,  61,  60,  59,  58,  56,  55,  53,  51,  49,  47, 
     45,  43,  41,  38,  36,  33,  30,  27,  24,  22,  19,  16,  12,   9,   6,   3, 
      0,  -3,  -6,  -9, -12, -16, -19, -22, -24, -27, -30, -33, -36, -38, -41, -43,
    -45, -47, -49, -51, -53, -55, -56, -58, -59, -60, -61, -62, -63, -63, -64, -64,
    -64, -64, -64, -63, -63, -62, -61, -60, -59, -58, -56, -55, -53, -51, -49, -47, 
    -45, -43, -41, -38, -36, -33, -30, -27, -24, -22, -19, -16, -12,  -9,  -6,  -3
};

// Current drawing buffer for erasing/drwing lines
u8* draw_buffer;
#define VRAM_PAGE_C0 (u8*)CPCT_VMEM_START
#define VRAM_PAGE_40 (u8*)0x4000


// Rotate a input point around global origin point by a given 1/128 of circle angle
void rotatePoint (i16 *pt, u8 iAngle)
{
    i16 tmpX,tmpY,tmp,cos,sin;

    u8 cosAngle = iAngle+32;
    if (cosAngle >127) cosAngle -= 128;
    cos = sintable[cosAngle];
    sin = sintable[iAngle];

    tmpX = pt[0] - origin[0];
    tmpY = pt[1] - origin[1];

    tmp = (tmpX * cos - tmpY * sin) >> 6;
    pt[0] = tmp  + origin[0];

    tmp = (tmpX * sin + tmpY * cos) >> 6;
    pt[1] = tmp + origin[1];
}

// Draw two lines from fixedPoints to the list of points
// rotating each points given an input angle based on a buffer index (0 or 1) to store drawn points
void drawLine (u8 col, u8 buff, u8 iAngle)
{
    u8 drBuf,cur;
    i16 *ptrPt, *drPoint;
    cur = 0;
    drBuf = (buff ? NBPTDR:0);  // Each buffer has its own temporary points

    for (u8 i=0;i<NBPOINT;i++)
    {
        // For each point, rotate it and draw 2 lines from each fixed point to this point
        // Computed clamped points are stored in drawnPoints for easy erasing
        ptrPt = (i16*)&ptList [cur];
        drPoint = (i16*)&drawnPoint [drBuf];

        drPoint[0] = ptrPt[0];
        drPoint[1] = ptrPt[1];
        rotatePoint (drPoint,iAngle);
        drPoint[2] = drPoint[0];
        drPoint[3] = drPoint[1];

        // Clamping can return 1 if the line cannot be drawn because both points are outside of screen
        // Cannot happen with fixedPoints inside screen, but we check it anyway so you can play with
        // the code to modify origin / fixedPoints and see what happens
        if ( !cpct_clampLineM1 (ptFixe1,drPoint) )
            cpct_drawLineM1_f (draw_buffer, ptFixe1[0], ptFixe1[1], drPoint[0],drPoint[1],col);
        else
            drPoint[0] = -1; // Mark the point X coordinate as not drawn, so it will not be erased later

        if ( !cpct_clampLineM1 (ptFixe2,&drPoint[2]) )
            cpct_drawLineM1_f (draw_buffer, drPoint[2],drPoint[3],ptFixe2[0],ptFixe2[1],col);
        else
            drPoint[2] = -1; // Mark the second point X as not drawn

        drBuf += 4; // Move to next storage
        cur   += 2; // Move to next point
    }
}

// Erase previously drawn lines by drawing stored points with color 0
void eraseLine (u8 buff)
{
    u8 drBuf = (buff ? NBPTDR:0);
    i16 *drPoint;

    for (u8 i=0;i<NBPOINT;i++)
    {
        drPoint = (i16*)&drawnPoint [drBuf];
        if (drPoint[0]>=0) // If first drawing drPoint[0] is -1
        {
            cpct_drawLineM1_f (draw_buffer, ptFixe1[0],ptFixe1[1],drPoint[0],drPoint[1],0);
            cpct_drawLineM1_f (draw_buffer, drPoint[2],drPoint[3],ptFixe2[0],ptFixe2[1],0);
        }
        drBuf += 4; 
    }
}

int main (void)
{
    cpct_disableFirmware();
    cpct_setBorder (HW_GREEN);

    u8 buffer_index = 0;
    u8 angle = 0;

    while (1)
    {
        if (buffer_index == 0) 
        {
            cpct_setVideoMemoryPage(cpct_page40);
            draw_buffer = VRAM_PAGE_C0;
        } 
        else 
        {
            cpct_setVideoMemoryPage(cpct_pageC0);
            draw_buffer = VRAM_PAGE_40;
        }

        eraseLine (buffer_index);  // Remove previously drawn lines
        drawLine (2,buffer_index,angle); // Draw new lines    
    
//        cpct_waitVSYNC();

        buffer_index = 1 - buffer_index; // Swap buffer_index
        angle++;
        if (angle > 127) angle -= 128;
    }

    return 0;
}
