module divide_clock_by_4(input in,output out);
	reg [2:0] count; 
	always @(posedge in) begin
		count <= count + 1;
	end
	assign out = count[2];
endmodule

module divide_clock_by_8(input in,output out);
	reg [3:0] count;
	always @(posedge in) begin
		count <= count + 1;
	end
	assign out = count[3];
endmodule

module toplevel(ad,rxf_,txe_,rd_,wr_,siwub,clk,clk50,oe_,ws2811);
	input [7:0] ad;
	input rxf_,txe_,clk,clk50;
	output rd_,wr_,siwub,oe_,ws2811;
	
	
	
	wire clk12_8, // minimum useful freq that can be generated from 60MHz
	     clk3_2,  // frequency of the four parts that make up one 1.25us cell
		  clk800,  // one bit in the ws2811 stream (1.25us cells)
		  clk100;  // one byte in the ws2811 stream
	pll c1(.inclk0(clk50),.c0(clk12_8));
	divide_clock_by_4 c2(clk12_8,clk3_2);
	divide_clock_by_4 c3(clk3_2,clk800);
	//divide_clock_by_8 c4(clk800,clk100);

	wire	  rdclk,rdreq,wrreq;
	wire [7:0] q_fifo;
	wire	  rdempty,rdfull;
	wire	  wrempty,wrfull;
	reg [7:0] ad_reg;
	
	fifo f (.data(ad_reg),
	.rdclk(clk800),	.rdreq(rdreq),
	.wrclk(clk50),		.wrreq(wrreq),
	.q(q_fifo),
	.rdempty(rdempty),.rdfull(rdfull),
	.wrempty(wrempty),.wrfull(wrfull));
		
	reg read_ftdi_p;
	always @(posedge clk50) begin
		read_ftdi_p <= (rxf_==1'b0);  // ftdi signals it can be read
	end
		
	assign oe_ = !read_ftdi_p;	// set ftdi data port to output/input
	assign rd_ = !read_ftdi_p;
	
	
	reg [1:0] evencount;
	always @(posedge clk50) begin
		//if(read_ftdi_p & ~oe_ & ~wrfull)
		//	ad_reg[7:0] <= ad[7:0];
		evencount <= evencount + 1;
		ad_reg[7:0] <= (evencount==0) ? 8'b0 : 8'b111111111;
	end

   reg fillfifo;
   always @(posedge clk50) begin
		fillfifo <= fillfifo ? ~wrfull : wrempty; // stop when full, start when empty
	end
	
	assign wr_ = 1'b1;

	assign wrreq = fillfifo; // & read_ftdi_p;
	
	reg consumefifo;
	always @(posedge clk3_2) begin
		consumefifo <= consumefifo ? ~rdempty : rdfull; // stop when empty, start when full
	end
	
	assign rdreq = consumefifo;
	
	reg muxbit, muxsub;
	//reg [2:0] sub = 8'b100011100
	reg [3:0] suboff = 4'b1000, subon = 4'b1110;
	reg [2:0] bitcount;
	reg [1:0] subcount; // index for one of the 4 subcells in 1.25us
	
	wire clk12_5;
	divide_clock_by_4(clk50,clk12_5);
	
	always @(posedge clk3_2) begin
		if(subcount == 2'b00) begin // go to next bit when 4 subcells were produced
			muxbit <= consumefifo ? q_fifo[bitcount] : 1'b0;
			bitcount <= bitcount + 1;
		end
		muxsub <= muxbit ? subon[subcount] : suboff[subcount];
		subcount <= subcount + 1;
	end
	assign ws2811 = muxsub; // e16 not at rectangle
endmodule