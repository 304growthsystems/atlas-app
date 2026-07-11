export interface NavigationItem {
  label: string;
  href: `/${string}`;
}

export const navigationItems = [
  { label: "Dashboard", href: "/dashboard" },
  { label: "Campaigns", href: "/campaigns" },
  { label: "Advertisers", href: "/advertisers" },
  { label: "Sales Pipeline", href: "/pipeline" },
  { label: "Artwork", href: "/artwork" },
  { label: "Payments", href: "/payments" },
  { label: "Tasks", href: "/tasks" },
  { label: "Reports", href: "/reports" },
] as const satisfies readonly NavigationItem[];
