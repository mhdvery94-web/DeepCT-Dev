import Image from "next/image";
import Link from "next/link";

export function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <Link className="brand" href="/" aria-label="BRIN Neutron CT Platform">
      <Image
        src="/assets/BRIN.png"
        alt=""
        width={44}
        height={44}
        className="brand__mark"
        priority
      />
      <span className="brand__copy">
        <strong>BRIN</strong>
        {!compact && <small>Neutron CT Platform</small>}
      </span>
    </Link>
  );
}
