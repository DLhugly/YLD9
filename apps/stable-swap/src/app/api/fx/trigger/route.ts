import { NextRequest, NextResponse } from "next/server";

// Placeholder endpoint for future trigger wiring. Returns 501 to indicate not implemented.
export async function GET(_req: NextRequest) {
  return NextResponse.json({ status: "NOT_IMPLEMENTED" }, { status: 501 });
}



