/**
 * The copyrights, all other intellectual and industrial 
 * property rights are retained by XMOS and/or its licensors. 
 * Terms and conditions covering the use of this code can
 * be found in the Xmos End User License Agreement.
 *
 * Copyright XMOS Ltd 2013
 *
 * In the case where this code is a modification of existing code
 * under a separate license, the separate license terms are shown
 * below. The modifications to the code are still covered by the 
 * copyright notice above.
 **/                                   

#include "lcd.h"

/*****************************************************************************/
void lcd_ports_init( // Initiate the LCD ports
	LCD_INTERFACE_TYP  &p // Reference to structure containing LCD interface data
)
{
	p.p_lcd_cs_n <: 1;

	p.p_lcd_sclk <: 1;
	sync(p.p_lcd_sclk);

	p.p_lcd_sclk <: 0;
	sync(p.p_lcd_sclk);

	p.p_lcd_sclk <: 1;
	sync(p.p_lcd_sclk);

	p.p_lcd_sclk <: 0;
	sync(p.p_lcd_sclk);

	p.p_lcd_sclk <: 1;
	sync(p.p_lcd_sclk);

	p.p_lcd_sclk <: 0;
	sync(p.p_lcd_sclk);

	// Now initialize the device
	lcd_comm_out(p, 0xE2);		/* RESET */
	lcd_comm_out(p, 0xA0);		/* RAM->SEG output = normal */
	lcd_comm_out(p, 0xAE);		/* Display OFF */
	lcd_comm_out(p, 0xC0);		/* COM scan direction = normal */
	lcd_comm_out(p, 0xA2);		/* 1/9 bias */
	lcd_comm_out(p, 0xC8);		/*  Reverse */
	lcd_comm_out(p, 0x2F);		/* power control set */
	lcd_comm_out(p, 0x20);		/* resistor ratio set */
	lcd_comm_out(p, 0x81);		/* Electronic volume command (set contrast) */
	lcd_comm_out(p, 0x3F);		/* Electronic volume value (contrast value) */
	lcd_clear(p);				/* Clear the display RAM */
	lcd_comm_out(p, 0xB0);		/* Reset page and column addresses */
	lcd_comm_out(p, 0x10);		/* column address upper 4 bits + 0x10 */
	lcd_comm_out(p, 0x00);		/* column address lower 4 bits + 0x00 */
} // lcd_ports_init 
/*****************************************************************************/
// Send a byte out to the LCD
void lcd_byte_out(
	LCD_INTERFACE_TYP &p, // Reference to structure containing LCD interface data
	unsigned char c, 
	int is_data
)
{
	unsigned int i;
	unsigned int data = (unsigned int) c;

	// Select the display
	p.p_lcd_cs_n <: 0;

	if (is_data)
	{
		// address
		p.p_core1_shared <: 1;
	}
	else
	{
		// command
		p.p_core1_shared <: 0;
	}

	// Loop through all 8 bits
	#pragma loop unroll
	for ( i = 0; i < 8; i++)
	{
		// MSb-first bit order - SPI standard
		p.p_lcd_mosi <: ( data >> (7 - i));
		sync(p.p_lcd_mosi);

		// Send the clock high
		p.p_lcd_sclk <: 1;
		sync(p.p_lcd_sclk);

		// Send the clock low
		p.p_lcd_sclk <: 0;
		sync(p.p_lcd_sclk);
	}

	// Deselect the display
	p.p_lcd_cs_n <: 1;

} // lcd_byte_out
/*****************************************************************************/
void lcd_clear( // Clear the display
	LCD_INTERFACE_TYP &p // Reference to structure containing LCD interface data
)
{
	unsigned int i, j, n = 0;
	unsigned char page = 0xB0;						// Page Address + 0xB0

	lcd_comm_out(p, 0xAE);				// Display OFF
	lcd_comm_out(p, 0x40);				// Display start address + 0x40
	lcd_comm_out(p, 0xA7);				// Invert

#pragma loop unroll
#pragma unsafe arrays
	for (i=0; i < 4; i++)							// 32 pixel display / 8 pixels per page = 4 pages
	{
		lcd_comm_out(p, page);			// send page address
		lcd_comm_out(p, 0x10);			// column address upper 4 bits + 0x10
		lcd_comm_out(p, 0x00);			// column address lower 4 bits + 0x00

		for (j=0; j < 128; j++)						// 128 columns wide
		{
			// Send the blank data
			lcd_data_out(p, 0x00);
			n++;									// point to next picture data
		}

		page++;										// after 128 columns, go to next page
	}

	lcd_comm_out(p, 0xAF);				// Display ON
} // lcd_clear 
/*****************************************************************************/
void lcd_draw_image( // Draw an image to the display
	const unsigned char image[], 
	LCD_INTERFACE_TYP &p // Reference to structure containing LCD interface data
)
{
	unsigned int i, j, n = 0;
	unsigned char page = 0xB0;						// Page Address + 0xB0

	lcd_comm_out(p, 0xAE);				// Display OFF
	lcd_comm_out(p, 0x40);				// Display start address + 0x40
	lcd_comm_out(p, 0xA7);				// Invert

#pragma loop unroll
#pragma unsafe arrays
	for (i=0; i < 4; i++)							// 32 pixel display / 8 pixels per page = 4 pages
	{
		lcd_comm_out(p, page);			// send page address
		lcd_comm_out(p, 0x10);			// column address upper 4 bits + 0x10
		lcd_comm_out(p, 0x00);			// column address lower 4 bits + 0x00

		for (j=0; j < 128; j++)						// 128 columns wide
		{
			lcd_data_out(p, image[n]);	// send picture data
			n++;									// point to next picture data
		}

		page++;										// after 128 columns, go to next page
	}

	lcd_comm_out(p, 0xAF);				// Display ON
} // lcd_draw_image
/*****************************************************************************/
void lcd_draw_text_row( // Draw a row of text to the display
	const char string[], 
	int lcd_row, 
	LCD_INTERFACE_TYP &p // Reference to structure containing LCD interface data
)
{
	static unsigned char font[] = { // 5x7 font characters
		0x00, 0x00, 0x00, 0x00, 0x00,// (space)
		0x00, 0x00, 0x5F, 0x00, 0x00,// !
		0x00, 0x07, 0x00, 0x07, 0x00,// "
		0x14, 0x7F, 0x14, 0x7F, 0x14,// #
		0x24, 0x2A, 0x7F, 0x2A, 0x12,// $
		0x23, 0x13, 0x08, 0x64, 0x62,// %
		0x36, 0x49, 0x55, 0x22, 0x50,// &
		0x00, 0x05, 0x03, 0x00, 0x00,// '
		0x00, 0x1C, 0x22, 0x41, 0x00,// (
		0x00, 0x41, 0x22, 0x1C, 0x00,// )
		0x08, 0x2A, 0x1C, 0x2A, 0x08,// *
		0x08, 0x08, 0x3E, 0x08, 0x08,// +
		0x00, 0x50, 0x30, 0x00, 0x00,// ,
		0x08, 0x08, 0x08, 0x08, 0x08,// -
		0x00, 0x30, 0x30, 0x00, 0x00,// .
		0x20, 0x10, 0x08, 0x04, 0x02,// /
		0x3E, 0x51, 0x49, 0x45, 0x3E,// 0
		0x00, 0x42, 0x7F, 0x40, 0x00,// 1
		0x42, 0x61, 0x51, 0x49, 0x46,// 2
		0x21, 0x41, 0x45, 0x4B, 0x31,// 3
		0x18, 0x14, 0x12, 0x7F, 0x10,// 4
		0x27, 0x45, 0x45, 0x45, 0x39,// 5
		0x3C, 0x4A, 0x49, 0x49, 0x30,// 6
		0x01, 0x71, 0x09, 0x05, 0x03,// 7
		0x36, 0x49, 0x49, 0x49, 0x36,// 8
		0x06, 0x49, 0x49, 0x29, 0x1E,// 9
		0x00, 0x36, 0x36, 0x00, 0x00,// :
		0x00, 0x56, 0x36, 0x00, 0x00,// ;
		0x00, 0x08, 0x14, 0x22, 0x41,// <
		0x14, 0x14, 0x14, 0x14, 0x14,// =
		0x41, 0x22, 0x14, 0x08, 0x00,// >
		0x02, 0x01, 0x51, 0x09, 0x06,// ?
		0x32, 0x49, 0x79, 0x41, 0x3E,// @
		0x7E, 0x11, 0x11, 0x11, 0x7E,// A
		0x7F, 0x49, 0x49, 0x49, 0x36,// B
		0x3E, 0x41, 0x41, 0x41, 0x22,// C
		0x7F, 0x41, 0x41, 0x22, 0x1C,// D
		0x7F, 0x49, 0x49, 0x49, 0x41,// E
		0x7F, 0x09, 0x09, 0x01, 0x01,// F
		0x3E, 0x41, 0x41, 0x51, 0x32,// G
		0x7F, 0x08, 0x08, 0x08, 0x7F,// H
		0x00, 0x41, 0x7F, 0x41, 0x00,// I
		0x20, 0x40, 0x41, 0x3F, 0x01,// J
		0x7F, 0x08, 0x14, 0x22, 0x41,// K
		0x7F, 0x40, 0x40, 0x40, 0x40,// L
		0x7F, 0x02, 0x04, 0x02, 0x7F,// M
		0x7F, 0x04, 0x08, 0x10, 0x7F,// N
		0x3E, 0x41, 0x41, 0x41, 0x3E,// O
		0x7F, 0x09, 0x09, 0x09, 0x06,// P
		0x3E, 0x41, 0x51, 0x21, 0x5E,// Q
		0x7F, 0x09, 0x19, 0x29, 0x46,// R
		0x46, 0x49, 0x49, 0x49, 0x31,// S
		0x01, 0x01, 0x7F, 0x01, 0x01,// T
		0x3F, 0x40, 0x40, 0x40, 0x3F,// U
		0x1F, 0x20, 0x40, 0x20, 0x1F,// V
		0x7F, 0x20, 0x18, 0x20, 0x7F,// W
		0x63, 0x14, 0x08, 0x14, 0x63,// X
		0x03, 0x04, 0x78, 0x04, 0x03,// Y
		0x61, 0x51, 0x49, 0x45, 0x43,// Z
		0x00, 0x00, 0x7F, 0x41, 0x41,// [
		0x02, 0x04, 0x08, 0x10, 0x20,// "\"
		0x41, 0x41, 0x7F, 0x00, 0x00,// ]
		0x04, 0x02, 0x01, 0x02, 0x04,// ^
		0x40, 0x40, 0x40, 0x40, 0x40,// _
		0x00, 0x01, 0x02, 0x04, 0x00,// `
		0x20, 0x54, 0x54, 0x54, 0x78,// a
		0x7F, 0x48, 0x44, 0x44, 0x38,// b
		0x38, 0x44, 0x44, 0x44, 0x20,// c
		0x38, 0x44, 0x44, 0x48, 0x7F,// d
		0x38, 0x54, 0x54, 0x54, 0x18,// e
		0x08, 0x7E, 0x09, 0x01, 0x02,// f
		0x08, 0x14, 0x54, 0x54, 0x3C,// g
		0x7F, 0x08, 0x04, 0x04, 0x78,// h
		0x00, 0x44, 0x7D, 0x40, 0x00,// i
		0x20, 0x40, 0x44, 0x3D, 0x00,// j
		0x00, 0x7F, 0x10, 0x28, 0x44,// k
		0x00, 0x41, 0x7F, 0x40, 0x00,// l
		0x7C, 0x04, 0x18, 0x04, 0x78,// m
		0x7C, 0x08, 0x04, 0x04, 0x78,// n
		0x38, 0x44, 0x44, 0x44, 0x38,// o
		0x7C, 0x14, 0x14, 0x14, 0x08,// p
		0x08, 0x14, 0x14, 0x18, 0x7C,// q
		0x7C, 0x08, 0x04, 0x04, 0x08,// r
		0x48, 0x54, 0x54, 0x54, 0x20,// s
		0x04, 0x3F, 0x44, 0x40, 0x20,// t
		0x3C, 0x40, 0x40, 0x20, 0x7C,// u
		0x1C, 0x20, 0x40, 0x20, 0x1C,// v
		0x3C, 0x40, 0x30, 0x40, 0x3C,// w
		0x44, 0x28, 0x10, 0x28, 0x44,// x
		0x0C, 0x50, 0x50, 0x50, 0x3C,// y
		0x44, 0x64, 0x54, 0x4C, 0x44,// z
		0x00, 0x08, 0x36, 0x41, 0x00,// {
		0x00, 0x00, 0x7F, 0x00, 0x00,// |
		0x00, 0x41, 0x36, 0x08, 0x00,// }
		0x08, 0x08, 0x2A, 0x1C, 0x08,// ->
		0x08, 0x1C, 0x2A, 0x08, 0x08 // <-
	};

	unsigned int i = 0, offset, col_pos = 0;
	unsigned char page = 0xB0 + lcd_row;		// Page Address + 0xB0 + row

	lcd_comm_out(p, 0xAE);			// Display OFF
	lcd_comm_out(p, 0x40);			// Display start address + 0x40
	lcd_comm_out(p, 0xA6);			// Non invert
	lcd_comm_out(p, page);			// Update page address
	lcd_comm_out(p, 0x10);			// column address upper 4 bits + 0x10
	lcd_comm_out(p, 0x00);			// column address lower 4 bits + 0x00

	// Loop through all the characters
	while (1)
	{
		char c = string[i];
		// If we are at the end of the string, or it's too long, break.
		if ((c == '\0') || (c == '\n') || (i >= 21 ))
		{
			break;
		}

		// Check char is in range, otherwise unsafe arrays break
		if ((c < 32) || (c > 127))
		{
			// If not, print a space instead
			c = ' ';
		}

#pragma unsafe arrays
		// Calculate the offset into the array
		offset = (c - 32) * FONT_WIDTH;

		// Print a char, along with a space between chars
		lcd_data_out(p, font[offset++]);
		lcd_data_out(p, font[offset++]);
		lcd_data_out(p, font[offset++]);
		lcd_data_out(p, font[offset++]);
		lcd_data_out(p, font[offset++]);
		lcd_data_out(p, 0x00);

		// Mark that we have written 6 rows
		col_pos += 6;

		// Move onto the next char
		i++;
	}

	// Blank the rest of the row
	while ( col_pos <= 127 )
	{
		lcd_data_out(p, 0x00);
		col_pos++;
	}

	lcd_comm_out(p, 0xAF);			// Display ON
} // lcd_draw_text_row 
/*****************************************************************************/