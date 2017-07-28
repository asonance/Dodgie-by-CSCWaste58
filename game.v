module Dodgie(
	CLOCK_50,						//	On Board 50 MHz
	// Your inputs and outputs here
    KEY,
    SW,
	 LEDR,
	 HEX0,
	 HEX1,
	 HEX2,
	 HEX5,
	 HEX6,
	 HEX7,
	// The ports below are for the VGA output.  Do not change.
	VGA_CLK,   						//	VGA Clock
	VGA_HS,							//	VGA H_SYNC
	VGA_VS,							//	VGA V_SYNC
	VGA_BLANK_N,					//	VGA BLANK
	VGA_SYNC_N,						//	VGA SYNC
	VGA_R,   						//	VGA Red[9:0]
	VGA_G,	 						//	VGA Green[9:0]
	VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input   [17:0]  SW;
	input   [3:0]   KEY;

	// Declare your inputs and outputs here
	output reg [17:6] LEDR;
	output [6:0] HEX0, HEX1, HEX2, HEX5, HEX6, HEX7;
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;			//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	wire resetn, clk, ran_l, lvl_clk;
	wire [7:0] ran1, ran2;
	
	assign resetn = KEY[0];
	assign ran_l = ran_load;

	DivCount d1(
		.dIn(1'b1), 
		.clock(CLOCK_50), 
		.reset(resetn), 
		.load(20'b01111111001111110011), 
		.qOut(clk)
		);
		
	DivCount level_clock(
		.dIn(1'b1), 
		.clock(CLOCK_50), 
		.reset(resetn), 
		.load(29'b11101110011010110010011111111), 
		.qOut(lvl_clk),
		);
	
	RanNum r1(
	.out(ran1),
	.load(8'b11001011),
	.start(ran_l),
	.clk(CLOCK_50),
	);
	
	RanNum r2(
	.out(ran2),
	.load(8'b01010101),
	.start(ran_l),
	.clk(CLOCK_50),
	);

	hex_decoder h0(
		.hex_digit(score[3:0]),
		.segments(HEX0)
	);
	
	hex_decoder h1(
		.hex_digit(score[7:4]),
		.segments(HEX1)
	);
	
	hex_decoder h2(
		.hex_digit(score[11:8]),
		.segments(HEX2)
	);

	hex_decoder h5(
		.hex_digit(highest_score[3:0]),
		.segments(HEX5)
	);
	
	hex_decoder h6(
		.hex_digit(highest_score[7:4]),
		.segments(HEX6)
	);
	
	hex_decoder h7(
		.hex_digit(highest_score[11:8]),
		.segments(HEX7)
	);
	
	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(1'b1),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "320x240";		// 0 == top/left, n == bottom/right
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "play_background.mif";
	
	reg ran_load;							// LFSR loader
	
	// Stage Values (User Loaded)
	wire [7:0] st_yt, st_yb;				// Upper & Lower stage bound
	wire [2:0] st_c;						// Stage color
	
	assign st_yt	= 8'd103;				//
	assign st_yb	= 8'd210;				// Load User defined values
	assign st_c		= 3'b111;				//	
	
	// General Use Params
	reg [2:0] 	colour;						// Sets colour to VGA
	reg [8:0]	x;							// Sets x to VGA
	reg [7:0] 	y;							// Sets y to VGA
	reg [8:0] dead_x;
	reg [7:0] dead_y;
	
	// General State Params
	reg [5:0] 	state;						// Current state
	reg [6:0]	level;						// Current level
	reg         next_level;              // 1 if its time to go to the next level
	
	// General Element State Params
	reg [8:0] 	s1_x, s2_x, b1_x, b2_x, b3_x, b4_x;			// The x of all elements
	reg [7:0] 	s1_y, s2_y, b1_y, b2_y, b3_y, b4_y;			// The y of all elements
	reg [2:0]   s1_c, s2_c, b1_c, b2_c, b3_c, b4_c;			// The color of all elements
	reg [2:0]	s1_s, s2_s, b1_s, b2_s, b3_s, b4_s;			// The speed of all elements
	
	// Slider Params
	reg 		s1_d, s2_d;					// The direction of Sliders
	
	// Ball Params
	reg 		b1_dx, b1_dy, b2_dx, b2_dy, b3_dx, b3_dy, b4_dx, b4_dy;				// The direction of all balls
	reg [7:0] 	b1_off, b2_off, b3_off, b4_off;						// The offset of all balls
	reg 		b1_w, b2_w, b3_w, b4_w;						// The wave state of all balls
	reg			b1_l, b2_l, b3_l, b4_l;						// The live state of all balls
	
	// Counter Params
	reg [17:0] 	draw;						// Universal counter for drawing stuff
	reg [15:0] 	ran;						// Universal random number
	reg [7:0]	b1_co, b2_co, b3_co, b4_co;						// The offset counter of all balls
	reg [25:0] FLINKHR_counter;
	
	// score params
	reg  [11:0] score;
	reg  [11:0] highest_score;
	
	// FSM (Note to self: max currently 10110)
	localparam						//
				INIT_R	 = 6'b000000,	// Naming scheme for the mathemtically mature
				INIT_T1	 = 6'b000001,
				INIT_T2	 = 6'b000010,
				INIT_B1	 = 6'b000011,	//
				INIT_B2   = 6'b000100,
				INIT_B3   = 6'b000101,
				INIT_B4   = 6'b000110,
				INIT_S1	 = 6'b000111,	// Let the alphabet of B58, denoted Σ, be defined such that
				INIT_S2   = 6'b001000, // Σ = {"INIT", "DRAW", "DEL", "UP", "WAIT", "S", "B", "_",
				DRAW_B1	 = 6'b001001, // "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}
				DRAW_B2	 = 6'b001010, // "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}
				DRAW_S1	 = 6'b001011, // 
				DRAW_S2   = 6'b001100,	// Let the name of the localparam, x, be the language over alphabet Σ st
				WAIT	    = 6'b001101,	// L(x) = {x: "WAIT" + (("INIT" + "DRAW" + "DEL" + "UP") ○ "_" ○ ("B" + "S")
				DEL_B1	 = 6'b001110,	// 		   ○ ("1" + "2" + "3" + "4" + "5" + "6" + "7" + "8" + "9")
				DEL_B2	 = 6'b001111, 
				DEL_S1	 = 6'b010000,	//         ○ ("0" + "1" + "2" + "3" + "4" + "5" + "6" + "7" + "8" + "9")*}
				DEL_S2    = 6'b010001,	//
				UP_B1 	 = 6'b010010,	// eg. WAIT_B1, 285WAIT_INIT, INITDRAW_052, INIT_0 is not a valid regex
				UP_B2     = 6'b010011,
				UP_S1 	 = 6'b010100,	//	   INIT_B105336325, WAIT, UP_S9 is a valid regex
				UP_S2     = 6'b010101,	//
				LEVEL     = 6'b010110,  // Level 
				DRAW_B3	 = 6'b010111,
				DRAW_B4	 = 6'b011000,
				UP_B3     = 6'b011001,
				UP_B4     = 6'b011010,
				DEL_B3	 = 6'b011011,
				DEL_B4	 = 6'b011100,
				DIE_RB    = 6'b011101,
				DIE_BB    = 6'b011110,
				DIE_BR1   = 6'b011111,
				DIE_BR2   = 6'b100000,
				DIE_BR3   = 6'b100001,
				DIE_BS    = 6'b100010,
				DIE_RS1   = 6'b100011,
				DIE_RS2   = 6'b100100,
				FLINKHR   = 6'b100101,
				DEAD_WAIT = 6'b100110,
				CLEAR		 = 6'b100111;
   
	always @(posedge CLOCK_50)
	begin
		if (~resetn) begin
				state = CLEAR;
				score = 12'b0;
		end
		if(score[3:0] == 4'b1010) begin
			score[3:0] = 4'b0;
			score[7:4] = score[7:4] + 1'b1;
		end
		if (score[7:4] == 4'b1010) begin
			score[7:4] = 4'b0;
			score[11:8] = score[11:8] + 1'b1;
		end
		dead_x = 9'd60;
		dead_y = 8'd80;
		// checks for the next level
		if (lvl_clk) begin
			next_level = 1'b1;
		end
		ran_load = 1'b0;			// Reset load state
		ran = {ran1[0], ran2[4],
			   ran1[1], ran2[3], 
			   ran1[2], ran2[2], 	// Random number setup
			   ran1[3], ran2[1], 
			   ran1[4], ran2[0]};	
		
		colour 	= 3'b000;			//
		x 		= 9'b000000000;		// Reset general use registers
		y 		= 8'b00000000; 		//
		case (state)
			CLEAR: begin
				if (draw[16:0] < 17'b10110100101000001) begin
					if (draw[8:0] < 9'b101000001)
						x = draw[8:0];
					if (draw[16:9] < 8'b10110101)
						y = 6'b111100 + draw[16:9];
					draw = draw + 1'b1;
				end
				else begin
					draw = 18'd0;
					state = INIT_R;
				end
			end
			INIT_R: begin
				ran_load = 1'b1;
				level = 4'b0001;
				state = INIT_T1;
				next_level = 1'b0;
			end
			INIT_T1: begin
				if (draw < 11'b10000000000) begin
					x = draw[8:0];
					y = st_yt - draw[10:9] - 1'b1;
					colour = st_c;
					draw = draw + 1'b1;
				end
				else begin
					draw = 18'b0;
					state = INIT_T2;
				end
			end
			INIT_T2: begin
				if (draw < 11'b10000000000) begin
					x = draw[8:0];
					y = st_yb + draw[10:9] + 1'b1;
					colour = st_c;
					draw = draw + 1'b1;
				end
				else begin
					draw = 18'b0;
					state = INIT_B1;
				end
			end
			INIT_B1: begin
				b1_x = 9'd2;
				b1_y = 9'd200;
				b1_c = 3'b100;
				b1_s = 3'b001;
				b1_w = 1'b0;
				b1_l = 1'b0;
				b1_off = 8'b00101011;
				state = INIT_B2;
			end
			INIT_B2: begin
				b2_x = 9'd319;
				b2_y = 3'd180;
				b2_c = 3'b100;
				b2_s = 3'b001;
				b2_w = 1'b0;
				b2_l = 1'b0;
				b2_off = 8'b00101011;
				b2_dx = 1'b1;
				state = INIT_B3;
			end
			INIT_B3: begin
				b3_x = 9'd0;
				b3_y = 9'd200;
				b3_c = 3'b100;
				b3_s = 3'b001;
				b3_w = 1'b0;
				b3_l = 1'b0;
				b3_off = 8'b00101011;
				state = INIT_B4;
			end
			INIT_B4: begin
				b4_x = 9'd318;
				b4_y = 3'd190;
				b4_c = 3'b100;
				b4_s = 3'b001;
				b4_w = 1'b0;
				b4_l = 1'b0;
				b4_dx = 1'b1;
				b4_off = 8'b00101011;
				state = INIT_S1;
			end
			INIT_S1: begin
				s1_x = 9'd130;
				s1_y = st_yb - 1'b1;
				s1_c = 3'b111;
				state = INIT_S2;
			end
			INIT_S2: begin
				s2_x = 9'd190;
				s2_y = st_yb - 1'b1;
				s2_c = 3'b111;
				state = DRAW_B1;
			end
			DRAW_B1: begin
				if (draw < 5'b10000) begin
					x = b1_x + draw[1:0];
					y = b1_y + draw[3:2];
					colour = b1_c;
					draw = draw + 1'b1;
				end 
				else begin
					draw = 18'd0;
					state = DRAW_B2;
				end
			end
			DRAW_B2: begin
				if (b2_l) begin
					if (draw < 5'b10000) begin
						x = b2_x + draw[1:0];
						y = b2_y + draw[3:2];
						colour = b2_c;
						draw = draw + 1'b1;
					end 
					else begin
						draw = 18'd0;
						state = DRAW_B3;
					end
				end
				else begin
					state = DRAW_B3;
				end
			end
			DRAW_B3: begin
				if (b3_l) begin
					if (draw < 5'b10000) begin
						x = b3_x + draw[1:0];
						y = b3_y + draw[3:2];
						colour = b3_c;
						draw = draw + 1'b1;
					end 
					else begin
						draw = 18'd0;
						state = DRAW_B4;
					end
				end
				else begin
					state = DRAW_B4;
				end
			end
			DRAW_B4: begin
				if (b4_l) begin
					if (draw < 5'b10000) begin
						x = b4_x + draw[1:0];
						y = b4_y + draw[3:2];
						colour = b4_c;
						draw = draw + 1'b1;
					end 
					else begin
						draw = 18'd0;
						state = DRAW_S1;
					end
				end
				else begin
					state = DRAW_S1;
				end
			end
			DRAW_S1: begin
				if (draw < 6'b100000) begin
					y = s1_y + draw[3:0];
					x = s1_x + draw[4];
					colour = s1_c;
					draw = draw + 1'b1;
				end 
				else begin
					draw = 18'd0;
					state = DRAW_S2;
				end
			end
			DRAW_S2: begin
				if (draw < 6'b100000) begin
					y = s2_y + draw[3:0];
					x = s2_x + draw[4];
					colour = s2_c;
					draw = draw + 1'b1;
				end 
				else begin
					draw = 18'd0;
					state = WAIT;
				end
			end
			WAIT: begin
				if (clk)
					state = DEL_B1;
			end
			DEL_B1: begin
				if (draw < 5'b10000) begin
					x = b1_x + draw[1:0];
					y = b1_y + draw[3:2];
					colour = 3'b000;
					draw = draw + 1'b1;
				end 
				else begin
					draw = 18'd0;
					state = DEL_B2;
				end
			end
			DEL_B2: begin
				if (draw < 5'b10000) begin
					x = b2_x + draw[1:0];
					y = b2_y + draw[3:2];
					colour = 3'b000;
					draw = draw + 1'b1;
				end 
				else begin
					draw = 18'd0;
					state = DEL_B3;
				end
			end
			DEL_B3: begin
				if (draw < 5'b10000) begin
					x = b3_x + draw[1:0];
					y = b3_y + draw[3:2];
					colour = 3'b000;
					draw = draw + 1'b1;
				end 
				else begin
					draw = 18'd0;
					state = DEL_B4;
				end
			end
			DEL_B4: begin
				if (draw < 5'b10000) begin
					x = b4_x + draw[1:0];
					y = b4_y + draw[3:2];
					colour = 3'b000;
					draw = draw + 1'b1;
				end 
				else begin
					draw = 18'd0;
					state = DEL_S1;
				end
			end
			DEL_S1: begin
				if (draw < 6'b100000) begin
					y = s1_y + draw[3:0];
					x = s1_x + draw[4];
					colour = 3'b000;
					draw = draw + 1'b1;
				end 
				else begin
					draw = 18'd0;
					state = DEL_S2;
				end
			end
			DEL_S2: begin
				if (draw < 6'b100000) begin
					y = s2_y + draw[3:0];
					x = s2_x + draw[4];
					colour = 3'b000;
					draw = draw + 1'b1;
				end 
				else begin
					draw = 18'd0;
					state = UP_B1;
				end
			end
			// Update ball one
			UP_B1: begin
			 if(b1_l) begin
					// Update x Position
					if (b1_dx) begin
						b1_x = b1_x - b1_s;
					end else begin
						b1_x = b1_x + b1_s;
					end
					// Update y Position
					if (b1_w) begin
						if (b1_dy)
							b1_y = b1_y - 1'b1;
						else
							b1_y = b1_y + 1'b1;
					end
					// Update x Edge
					if (b1_x >= 10'd316) begin
						b1_x = 10'd1;
						score = score + 1'b1;
						b1_y = st_yt + ran[5:0];
						b1_off = 7'b1111110;
						//b1_w = ran[0];
					end
					else if (b1_x <= 10'd1) begin
						b1_x = 10'd316;
						score = score + 1'b1;
						b1_y = st_yt + ran[5:0];
						b1_off = 7'b1111110;
						//b1_w = ran[0];
					end
					// Update y Edge
					if (b1_w) begin
						if ((b1_y + 2'b11 >= st_yb) || (b1_y <= st_yt)) begin
							b1_dy = ~b1_dy;
							b1_co = 8'b0;
						end
						else if (b1_co < b1_off) begin
							b1_co = b1_co + 1'b1;
						end
						else begin
							b1_dy = ~b1_dy;
							b1_co = 8'b0;
						end
					end
				
					
					// Update Collision
					// Check x
					if ((b1_x + 3'b100 == s1_x) || (b1_x == s1_x + 1'b1)) begin
						// Check y
						if (((b1_y >= s1_y + 5'b10000) && (b1_y + 3'b100 < s1_y)) || ((b1_y < s1_y + 5'b10000) && (b1_y + 3'b100 >= s1_y)))
							//b1_dx = ~b1_dx; 
							state = DIE_RB;
					end
					else if ((b1_x + 3'b100 == s2_x) || (b1_x == s2_x + 1'b1)) begin
						// Check y
						if (((b1_y >= s2_y + 5'b10000) && (b1_y + 3'b100 < s2_y)) || ((b1_y < s2_y + 5'b10000) && (b1_y + 3'b100 >= s2_y)))
							//b1_dx = ~b1_dx;
							state = DIE_RB;
					end
					else 
						state = UP_B2;
				end else begin
					state = UP_B2;
				end
			end
			// Update ball two
			UP_B2: begin
				if (b2_l) begin
					// Update x Position
					if (b2_dx)
						b2_x = b2_x - b2_s;
					else
						b2_x = b2_x + b2_s;
					
					// Update y Position
					if (b2_w) begin
						if (b2_dy)
							b2_y = b2_y - 1'b1;
						else
							b2_y = b2_y + 1'b1;
					end
					// Update x Edge
					if (b2_x >= 10'd316) begin
						b2_x = 10'd1;
						score = score + 1'b1;
						b2_y = st_yt + ran[5:0];
						b1_off = 7'b1111110;
						//b1_w = ran[0];
					end
					else if (b2_x <= 10'd1) begin
						b2_x = 10'd316;
						score = score + 1'b1;
						b2_y = st_yt + ran[5:0];
						b1_off = 7'b1111110;
						//b1_w = ran[0];
					end
					
					// Update y Edge
					if (b2_w) begin
						if ((b2_y + 2'b11 >= st_yb) || (b2_y <= st_yt)) begin
							b2_dy = ~b2_dy;
							b2_co = 8'b0;
						end 
						else if (b2_co < b2_off) begin
							b2_co = b2_co + 1'b1;
						end
						else begin
							b2_dy = ~b2_dy;
							b2_co = 8'b0;
						end
					end
					
					// Update Collision
					// Check x
					if ((b2_x + 3'b100 == s1_x) || (b2_x == s1_x + 1'b1)) begin
						// Check y
						if (((b2_y >= s1_y + 5'b10000) && (b2_y + 3'b100 < s1_y)) || ((b2_y < s1_y + 5'b10000) && (b2_y + 3'b100 >= s1_y)))
							//b2_dx = ~b2_dx;
							state = DIE_RB;
					end
					else if ((b2_x + 3'b100 == s2_x) || (b2_x == s2_x + 1'b1)) begin
						// Check y
						if (((b2_y >= s2_y + 5'b10000) && (b2_y + 3'b100 < s2_y)) || ((b2_y < s2_y + 5'b10000) && (b2_y + 3'b100 >= s2_y)))
							//b2_dx = ~b2_dx;
							state = DIE_RB;
					end
					else
						state = UP_B3;
				end else
					state = UP_B3;
			end
			// Update ball three
			UP_B3: begin
				if (b3_l) begin
					// Update x Position
					if (b3_dx)
						b3_x = b3_x - b3_s;
					else
						b3_x = b3_x + b3_s;
					
					// Update y Position
					if (b3_w) begin
						if (b3_dy)
							b3_y = b3_y - 1'b1;
						else
							b3_y = b3_y + 1'b1;
					end
					// Update x Edge
					if (b3_x >= 10'd316) begin
						b3_x = 10'd1;
						score = score + 1'b1;
						b3_y = st_yt + ran[7:2] + 4'd90;
						b1_off = 7'b1111110;
						//b1_w = ran[0];
					end
					else if (b3_x <= 10'd1) begin
						b3_x = 10'd316;
						score = score + 1'b1;
						b3_y = st_yt + ran[5:0] + 4'd100;
						b1_off = 7'b1111110;
						//b1_w = ran[0];
					end
					
					// Update y Edge
					if (b3_w) begin
						if ((b3_y + 2'b11 >= st_yb) || (b3_y <= st_yt)) begin
							b3_dy = ~b3_dy;
							b3_co = 8'b0;
						end 
						else if (b3_co < b3_off) begin
							b3_co = b3_co + 1'b1;
						end
						else begin
							b3_dy = ~b3_dy;
							b3_co = 8'b0;
						end
					end
					
					// Update Collision
					// Check x
					if ((b3_x + 3'b100 == s1_x) || (b3_x == s1_x + 1'b1)) begin
						// Check y
						if (((b3_y >= s1_y + 5'b10000) && (b3_y + 3'b100 < s1_y)) || ((b3_y < s1_y + 5'b10000) && (b3_y + 3'b100 >= s1_y)))
							//b3_dx = ~b3_dx;
							state = DIE_RB;
					end
					else if ((b3_x + 3'b100 == s2_x) || (b3_x == s2_x + 1'b1)) begin
						// Check y
						if (((b3_y >= s2_y + 5'b10000) && (b3_y + 3'b100 < s2_y)) || ((b3_y < s2_y + 5'b10000) && (b3_y + 3'b100 >= s2_y)))
							//b3_dx = ~b3_dx;
							state = DIE_RB;
					end
					else
						state = UP_B4;
				end else
					state = UP_B4;
			end
			// Update ball four
			UP_B4: begin
				if (b4_l) begin
					// Update x Position
					if (b4_dx)
						b4_x = b4_x - b4_s;
					else
						b4_x = b4_x + b4_s;
					
					// Update y Position
					if (b4_w) begin
						if (b4_dy)
							b4_y = b4_y - 1'b1;
						else
							b4_y = b4_y + 1'b1;
					end
					// Update x Edge
					if (b4_x >= 10'd316) begin
						b4_x = 10'd1;
						score = score + 1'b1;
						b4_y = st_yt + ran[7:2] + 4'd80;
						b1_off = 7'b1111110;
						//b1_w = ran[0];
					end
					else if (b4_x <= 10'd1) begin
						b4_x = 10'd316;
						score = score + 1'b1;
						b4_y = st_yt + ran[5:0] + 4'd80;
						b1_off = 7'b1111110;
						//b1_w = ran[0];
					end
					
					// Update y Edge
					if (b4_w) begin
						if ((b4_y + 2'b11 >= st_yb) || (b4_y <= st_yt)) begin
							b4_dy = ~b4_dy;
							b4_co = 8'b0;
						end 
						else if (b4_co < b4_off) begin
							b4_co = b4_co + 1'b1;
						end
						else begin
							b4_dy = ~b4_dy;
							b4_co = 8'b0;
						end
					end
					
					// Update Collision
					// Check x
					if ((b4_x + 3'b100 == s1_x) || (b4_x == s1_x + 1'b1)) begin
						// Check y
						if (((b4_y >= s1_y + 5'b10000) && (b4_y + 3'b100 < s1_y)) || ((b4_y < s1_y + 5'b10000) && (b4_y + 3'b100 >= s1_y)))
							//b4_dx = ~b4_dx;
							state = DIE_RB;
					end
					else if ((b4_x + 3'b100 == s2_x) || (b4_x == s2_x + 1'b1)) begin
						// Check y
						if (((b4_y >= s2_y + 5'b10000) && (b4_y + 3'b100 < s2_y)) || ((b4_y < s2_y + 5'b10000) && (b4_y + 3'b100 >= s2_y))) 
							//b4_dx = ~b4_dx;
							state = DIE_RB;
					end
					else
						state = UP_S1;
				end else
					state = UP_S1;
			end
			UP_S1: begin
				if (SW[17] && (s1_y != st_yt))
					s1_y = s1_y - 2'b10;
				else if (~SW[17] && (s1_y + 4'b1111 != st_yb))
					s1_y = s1_y + 2'b10;
				state = UP_S2;
			end
			UP_S2: begin
				if (SW[0] && (s2_y != st_yt))
					s2_y = s2_y - 2'b10;
				else if (~SW[0] && (s2_y + 4'b1111 != st_yb))
					s2_y = s2_y + 2'b10;
				state = LEVEL;
			end
			
			LEVEL: begin
				if (next_level) begin
					// Level 1
					if (level == 4'b0001) begin
						level = level + 1'b1;
						LEDR[17:6] = 12'b100000000000;
					end
					// level 2
					if (level == 4'b0010) begin
						// Increase the speed of the ball by 1
						b1_l = 1'b1;
						level = level + 1'b1;
					end
					// level 3
					else if (level == 4'b0011) begin
						// Makes ball 1 wave
						b1_w = 1'b1;
						level = level + 1'b1;
						LEDR[17:6] = 12'b110000000000;
					// level 4
					end
					else if (level == 4'b0100) begin
						// Makes b2 faster
					   //b2_s = b2_s + 1'b1;
						level = level + 1'b1;
						LEDR[17:6] = 12'b111000000000;
					end
					// Level 5
					else if (level == 4'b0101) begin 
						// b2 waves
						b2_l = 1'b1;
						level = level + 1'b1;
						b1_c = 3'b111;
						LEDR[17:6] = 12'b111100000000;
					end
					// Level 6
					else if (level == 4'b0110) begin
						// makes b3 live
						//b2_s = b2_s + 1'b1;
						level = level + 1'b1;
						LEDR[17:6] = 12'b111110000000;
					end
					// level 7
					else if (level == 4'b0111) begin
						level = level + 1'b1;
						b1_c = 3'b010;
						LEDR[17:6] = 12'b111111000000;
					end
					// Level 8
					else if (level == 4'b1000) begin
						b2_w = 1'b1;
						b2_c = 3'b111;
						level = level + 1'b1;
						LEDR[17:6] = 12'b111111100000;
					end
					// Level 9
					else if (level == 4'b1001) begin
						b3_l = 1'b1;
						level = level + 1'b1;
						LEDR[17:6] = 12'b111111110000;
					end
					// Level 10
					else if (level == 4'b1010) begin
						b3_w = 1'b1;
						level = level + 1'b1;
						LEDR[17:6] = 12'b111111111000;
					end
					else if (level == 4'b1011) begin
						b3_c = 3'b011;
						b2_s = b2_s + 1'b1;
						level = level + 1'b1;
						LEDR[17:6] = 12'b111111111100;
					end
					else if (level == 4'b1100) begin
						b4_l = 1'b1;
						level = level + 1'b1;
						LEDR[17:6] = 12'b111111111110;
					end
					else if (level == 4'b1101) begin
						b4_w = 1'b1;
						b4_c = 3'b101;
						level = level + 1'b1;
						LEDR[17:6] = 12'b111111111111;
					end
					next_level = 1'b0;
				end
				state = DRAW_B1;
			end
			
			DIE_RB: begin;
				if (draw < 11'b10010110101) begin
					if (draw[10:5] < 6'b100101)
						x = dead_x + draw[10:5];
					if (draw[4:0] < 5'b10101)
						y = dead_y + draw[4:0];
					colour = 3'b100;
					draw = draw + 1'b1;
				end 
				else begin
					draw = 18'd0;
					state = DIE_BB;
				end
			end
			
			DIE_BB: begin
				if (draw < 9'b110110101) begin
					if (draw[8:5] < 4'b1101)
						x = dead_x + 9'd12 + draw[8:5];
					if (draw[4:0] < 5'b10101)
						y = dead_y + draw[4:0];
					draw = draw + 1'b1;
				end
				else begin
					draw = 18'd0;
					state = DIE_BR1;
				end
			end

			DIE_BR1: begin
				if (draw < 7'b1011001) begin
					if (draw[6:4] < 3'b101)
						x = dead_x + 9'd4 + draw[6:4];
					if (draw[3:0] < 4'b1001)
						y = dead_y + 8'd12 + draw[3:0];
					draw = draw + 1'b1;
				end
				else begin
					draw = 18'd0;
					state = DIE_BR2;
				end
			end

			DIE_BR2: begin
				if (draw < 7'b1011001) begin
					if (draw[6:4] < 3'b101)
						x = dead_x + 9'd4 + draw[6:4];
					if (draw[3:0] < 4'b1001)
						y = dead_y + draw[3:0];
					draw = draw + 1'b1;
				end
				else begin
					draw = 18'd0;
					state = DIE_BR3;
				end
			end

			DIE_BR3: begin
				if (draw < 7'b1011101) begin
					if (draw[6:4] < 3'b101)
						x = dead_x + 9'd28 + draw[6:4];
					if (draw[3:0] < 4'b1101)
						y = dead_y + 8'd4 + draw[3:0];
					draw = draw + 1'b1;
				end
				else begin
					draw = 18'd0;
					state = DIE_BS;
				end
			end

			DIE_BS: begin
				if (draw < 6'b101101) begin
					if (draw[2:0] < 3'b101)
						x = dead_x + 9'd8 + draw[2:0];
					if (draw[5:3] < 3'b101)
						y = dead_y + 8'd8 + draw[5:3];
					draw = draw + 1'b1;
				end
				else begin
					draw = 18'd0;
					state = DIE_RS1;
				end
			end

			DIE_RS1: begin
				if (draw < 6'b101101) begin
					if (draw[2:0] < 3'b101)
						x = dead_x + 9'd16 + draw[2:0];
					if (draw[5:3] < 3'b101)
						y = dead_y + 8'd16 + draw[5:3];
					colour = 3'b100;
					draw = draw + 1'b1;
				end
				else begin
					draw = 18'd0;
					state = DIE_RS2;
				end
			end

			DIE_RS2: begin
				if (score > highest_score)
					highest_score = score;		
				if (draw < 6'b101101) begin
					if (draw[2:0] < 3'b101)
						x = dead_x + 9'd40 + draw[2:0];
					if (draw[5:3] < 3'b101)
						y = dead_y + 8'd16 + draw[5:3];
					colour = 3'b100;
					draw = draw + 1'b1;
				end
				else begin
					draw = 18'd0;
					state = DEAD_WAIT;
				end
			end

			DEAD_WAIT: begin
				if (FLINKHR_counter[25:0] < 26'b10111110101111000001111111)
					FLINKHR_counter = FLINKHR_counter + 1'b1;
				else
					state = FLINKHR;
			end
			
			FLINKHR: begin
				if (draw[16:0] < 17'b10110100101000001) begin
					if (draw[8:0] < 9'b101000001)
						x = draw[8:0];
					if (draw[16:9] < 8'b10110101)
						y = 6'b111100 + draw[16:9];
					draw = draw + 1'b1;
				end
				else begin
					draw = 18'd0;
					FLINKHR_counter = 26'b0;
					state = DIE_RB;
				end
			end

		endcase
	end
endmodule

module DivCount(dIn, clock, reset, load, qOut);
	input dIn;              // Input(dIn) is signal in
	input clock;            // Input(clock) is clock signal
	input reset;            // Input(reset) is reset signal
	input [27:0] load;      // Input(load) is the number of clock cycles to count
	output reg qOut;        // Output(qOut) is 4-Bit output
	
	reg [27:0] count;       // Wire carrying a Count (Up to 250 Million)

	always @(posedge clock, negedge reset) // Active when the clock rises, reset falls
	begin
		if (reset == 1'b0)             // If reset is 1:
		begin
			count <= 0;            // Assign count to 0
		end
		
		else if (count == load)            // If the count is equal to the load:
		begin
				qOut <= 1'b1;      // Assign qOut to 1
				count <= 0;        // Reset the count to 0
		end

		else if (dIn)                              // If the input is 1
		begin
				count <= count + 1'b1;     // Increment the count by 1
				qOut <= 1'b0;              // Assign qOut to 1  
		end
	end
endmodule

module RanNum (
	output reg [7:0] out,
	input [7:0] load,
	input start, clk
	);
	
	wire linear_feedback;
	assign linear_feedback = !(out[7] ^ out[3]);

	always @(posedge clk)
		if (start) begin
			out <= load;
		end
		
		else begin
			out <= {out[6],out[5],out[4],out[3],out[2],out[1],out[0], linear_feedback};
		end 
endmodule

module hex_decoder(hex_digit, segments);
    input [3:0] hex_digit;
    output reg [6:0] segments;
   
    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_1000;  
            default: segments = 7'b111_1111;
        endcase
endmodule