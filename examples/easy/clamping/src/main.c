#include <cpctelera.h>

#define POINTI16  (u8)( 2 )
#define LINEI16  (u8)( 4 )
#define POINTSIZEOCTET  (u8)( 2 * POINTI16 )
#define LINESIZEOCTET   (u8)( 2 * LINEI16 )

// Triangle avec des sommets hors écran
const i16 ptList[] = {
    10, 20,         // In screen
    -10, 40,        // < XMin
    330, 60,        // > XMax
    80, -20,        // < YMin
    100, 220,       // > YMax
};

const i16 origine[] = { 80, 130 };

// 
#define NBPOINT      (u8)( 5 )
#define NBLINEBYDRAW (u8)( 2 )
#define NBLINES      (u8)( NBPOINT * NBLINEBYDRAW )
#define NBBUFFER     (u8)( 2 )

#define TOTALLINE    (u8)( NBLINES * NBBUFFER )

#define LINEBUFFER   (u8)(NBLINES * LINEI16 )
#define TOTALBUFFER  (u8)(TOTALLINE * LINEI16)

const i16 drawnLine [TOTALBUFFER] = {-1};   // Buffer for saving drawn lines on 2 screen buffer

const i8 sintable[64] =
{
      0,   6,  12,  18,  24,  30,  35,  40,  45,  49,  53,  56,  59,  61,  63,  63,
     64,  63,  63,  61,  59,  56,  53,  49,  45,  40,  35,  30,  24,  18,  12,   6,
      0,  -6, -12, -18, -24, -30, -35, -40, -45, -49, -53, -56, -59, -61, -63, -63,
    -64, -63, -63, -61, -59, -56, -53, -49, -45, -40, -35, -30, -24, -18, -12,  -6
};

#define VRAM_PAGE_C0 (u8*)CPCT_VMEM_START
#define VRAM_PAGE_40 (u8*)0x4000

u8* draw_buffer = VRAM_PAGE_40;

void rotatePolygon (i16 ptOrigine[2], u8 iAngle)
{
    i16 *ptPtr;
    u8 cosAngle, cur = 0;
    i32 tmpX,tmpY,tmp,cos,sin;
    for (u8 i=0;i<NBPOINT;i++)
    {
        ptPtr = (i16*)&ptList[cur];

        tmpX = ptPtr[0] - ptOrigine[0];
        tmpY = ptPtr[1] - ptOrigine[1];    

        cosAngle = iAngle+16;
        if (cosAngle >63) cosAngle -= 64;

        cos = sintable[cosAngle];
        sin = sintable[iAngle];

        tmp  = (tmpX * cos - tmpY * sin) >> 6;
        tmpY = (tmpX * sin + tmpY * cos) >> 6;

        ptPtr[0] = tmp  + ptOrigine[0];
        ptPtr[1] = tmpY + ptOrigine[1];
        cur+=2;
    }
}

void drawLine (u8 col, u8 buff)
{
    u8 drBuf,cur;
    i16 *cstPoly, *tmpLine;
    cur = 0;
    drBuf = (buff ? LINEBUFFER:0);  // Each buffer has its own temporary lines
    for (u8 i=0;i<NBPOINT;i++)
    {
        cstPoly = (i16*)ptList [cur];
        tmpLine = (i16*)&drawnLine [drBuf];

        tmpLine[0] = 140;
        tmpLine[1] = 110;
        tmpLine[2] = cstPoly[0];
        tmpLine[3] = cstPoly[1];
        if ( !cpct_clampLineM1 (&tmpLine[0],&tmpLine[2]) )
            cpct_drawLineM1 (draw_buffer, tmpLine[0],tmpLine[1],tmpLine[2],tmpLine[3],col);
        else
            tmpLine[0] = -1;  // Put saved points outside screen for 'no Drawn'

        tmpLine[4] = cstPoly[0];
        tmpLine[5] = cstPoly[1];
        tmpLine[6] = 220;
        tmpLine[7] = 150;
        if ( !cpct_clampLineM1 (&tmpLine[4],&tmpLine[6]) )
            cpct_drawLineM1 (draw_buffer, tmpLine[4],tmpLine[5],tmpLine[6],tmpLine[7],col);
        else
            tmpLine[4] = -1;  // Put saved points outside screen for 'no Drawn'

        drBuf  += 8;
        cur  += 2;
    }
}

void eraseLine (u8 buff)
{
    u8 drBuf = (buff ? LINEBUFFER:0);
    i16 *tmpLine;

    for (u8 i=0;i<NBPOINT;i++)
    {
        tmpLine = (i16*)&drawnLine [drBuf];
        if (tmpLine[0] > 0)
            cpct_drawLineM1 (draw_buffer, tmpLine[0],tmpLine[1],tmpLine[2],tmpLine[3],0);
        if (tmpLine[4] > 0)
            cpct_drawLineM1 (draw_buffer, tmpLine[4],tmpLine[5],tmpLine[6],tmpLine[7],0);
        drBuf += 8; 
    }
}

int main (void)
{
    cpct_disableFirmware();
    cpct_setBorder (HW_GREEN);

    u8 angle = 0;
    u8 buffer_index = 0;

    draw_buffer = VRAM_PAGE_C0;

    while (1)
    {
        eraseLine (buffer_index);  // Remove previously drawn lines
        drawLine (2,buffer_index); // Draw new lines
        rotatePolygon (origine,angle); // Rotate for next buffer

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
        buffer_index = 1 - buffer_index;

        angle += 1;
        if (angle > 63) angle -= 64;
        cpct_waitVSYNC();
    }

    return 0;
}
