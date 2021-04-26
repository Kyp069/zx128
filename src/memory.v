//-------------------------------------------------------------------------------------------------
module memory
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       ce,

	input  wire       reset,
	output wire       map,
	output wire       cn,

	input  wire       rfsh,
	input  wire       mreq,
	input  wire       iorq,
	input  wire       rd,
	input  wire       wr,
	input  wire       m1,
	input  wire[ 7:0] d,
	output wire[ 7:0] q,
	input  wire[15:0] a,

	input  wire       vce,
	output wire[ 7:0] vq,
	input  wire[12:0] va,

	output wire       ramRd,
	output wire       ramWr,
	output wire[ 7:0] ramD,
	input  wire[ 7:0] ramQ,
	output wire[17:0] ramA
);
//-------------------------------------------------------------------------------------------------

reg forcemap;
reg automap;
reg mapram;
reg m1on;
reg[3:0] mappage;

always @(posedge clock) if(ce)
if(!reset)
begin
	forcemap <= 1'b0;
	automap <= 1'b0;
	mappage <= 4'd0;
	mapram <= 1'b0;
	m1on <= 1'b0;
end
else
begin
	if(!iorq && !wr && a[7:0] == 8'hE3)
	begin
		forcemap <= d[7];
		mappage <= d[3:0];
		mapram <= d[6]|mapram;
	end

	if(!mreq && !m1)
	begin
		if(a == 16'h0000 || a == 16'h0008 || a == 16'h0038 || a == 16'h0066 || a == 16'h04C6 || a == 16'h0562)
			m1on <= 1'b1; // activate automapper after this cycle

		else if(a[15:3] == 13'h3FF)
			m1on <= 1'b0; // deactivate automapper after this cycle

		else if(a[15:8] == 8'h3D)
		begin
			m1on <= 1'b1; // activate automapper immediately
			automap <= 1'b1;
		end
	end

	if(m1) automap <= m1on;
end

//-------------------------------------------------------------------------------------------------

reg vduPage;
reg romPage;
reg noPaging;
reg[2:0] ramPage;

always @(posedge clock) if(ce)
if(!reset)
begin
	noPaging <= 1'b0;
	romPage <= 1'b0;
	vduPage <= 1'b0;
	ramPage <= 3'b000;
end
else if(!iorq && !a[15] && !a[1] && !wr && !noPaging)
begin
	noPaging <= d[5];
	romPage <= d[4];
	vduPage <= d[3];
	ramPage <= d[2:0];
end

//-------------------------------------------------------------------------------------------------

wire[ 7:0] romQ;
wire[14:0] romA = { romPage, a[13:0] };

rom #(.KB(32), .FN("+2.hex")) Rom
(
	.clock  (clock  ),
	.ce     (ce     ),
	.q      (romQ   ),
	.a      (romA   )
);

//-------------------------------------------------------------------------------------------------

wire[ 7:0] esxQ;
wire[12:0] esxA = a[12:0];

rom #(.KB(8), .FN("esxdos.hex")) Esx
(
	.clock  (clock  ),
	.ce     (ce     ),
	.q      (esxQ   ),
	.a      (esxA   )
);

//-------------------------------------------------------------------------------------------------

wire va01 = a[15:14] == 2'b01;
wire va11 = a[15:14] == 2'b11 && (ramPage == 3'd5 || ramPage == 3'd7);

wire dprWe2 = !(!mreq && !wr && (va01 || va11) && !a[13]);

wire[13:0] dprA1 = { vduPage, va[12:7], !rfsh && a[15:14] == 2'b01 ? a[6:0] : va[6:0] };
wire[13:0] dprA2 = { va11 ? ramPage[1] : 1'b0, a[12:0] };

dprs #(.KB(16)) Dpr
(
	.clock  (clock  ),
	.ce1    (vce    ),
	.q1     (vq     ),
	.a1     (dprA1  ),
	.ce2    (ce     ),
	.we2    (dprWe2 ),
	.d2     (d      ),
	.a2     (dprA2  )
);

//-------------------------------------------------------------------------------------------------

assign map = forcemap || automap;
wire[3:0] page = !a[13] && mapram ? 4'd3 : mappage;

assign ramRd = !(!mreq && !rd && (a[15] || a[14] || map));
assign ramWr = !(!mreq && !wr && (a[15] || a[14] || (a[13] && map)));
assign ramD = d;
assign ramA
	= a[15:14] == 2'b00 && map
	? { 1'b1, page, a[12:0] }
	: { 1'b0, a[15:14] == 2'b01 ? 3'd5 : a[15:14] == 2'b10 ? 3'd2 : ramPage , a[13:0] };

//-------------------------------------------------------------------------------------------------

assign cn = a[15:14] == 2'b11 && ramPage[0];

assign q = a[15:13] == 3'b000 && map && !mapram ? esxQ : a[15:14] == 2'b00 && !map ? romQ : ramQ;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
