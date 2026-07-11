interface PageContainerProps {
  children: React.ReactNode;
}

export function PageContainer({ children }: PageContainerProps) {
  return <div className="space-y-6 p-6 lg:p-8">{children}</div>;
}
