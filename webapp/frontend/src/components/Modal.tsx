import type { ReactNode } from "react";

interface ModalProps {
  title: string;
  /** Optional supporting line under the title (mockup `.msub`). */
  subtitle?: string;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
}

export function Modal({ title, subtitle, onClose, children, footer }: ModalProps) {
  return (
    <div
      className="modal-backdrop"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="modal" role="dialog" aria-modal="true" aria-label={title}>
        <h3>{title}</h3>
        {subtitle && <p className="msub">{subtitle}</p>}
        {children}
        {footer}
      </div>
    </div>
  );
}
