import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { getTrustedAppUrl } from "@/lib/security";

export async function GET(request: NextRequest) {
  const failure = getTrustedAppUrl("/login?error=auth_callback");
  const code = request.nextUrl.searchParams.get("code");
  if (!code) return NextResponse.redirect(failure);
  try {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (error) {
      console.error("Auth code exchange failed", { code: error.code });
      return NextResponse.redirect(failure);
    }
    return NextResponse.redirect(getTrustedAppUrl("/dashboard"));
  } catch (error) {
    console.error("Auth callback failed", error);
    return NextResponse.redirect(failure);
  }
}
