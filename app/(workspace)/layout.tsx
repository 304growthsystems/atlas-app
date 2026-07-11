import { ApplicationShell } from "@/components/application-shell/application-shell";
import { getCurrentContext } from "@/lib/auth";

export default async function WorkspaceLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  await getCurrentContext();
  return <ApplicationShell>{children}</ApplicationShell>;
}
