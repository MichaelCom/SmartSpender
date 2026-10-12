export function Spinner() {
  return <div className="spinner" aria-label="Loading" />;
}

export function ErrorBanner({ message }: { message: string | null }) {
  if (!message) return null;
  return <div className="error-banner">{message}</div>;
}

export function Empty({ text }: { text: string }) {
  return <div className="empty">{text}</div>;
}
