import { UiIcon } from "@/components/ui-icon";

export function CtIllustration() {
  return (
    <figure className="ct-illustration" aria-label="Illustration of CT frames and a reconstructed volume">
      <div className="ct-illustration__halo" aria-hidden="true" />
      <div className="ct-frame ct-frame--input" data-art-float>
        <div className="ct-frame__heading"><span><UiIcon name="database" size={16} /> Input frames</span><small>01 / 03</small></div>
        <svg className="ct-frame__projection" viewBox="0 0 220 230" aria-hidden="true">
          <defs><pattern id="ct-grid" width="22" height="22" patternUnits="userSpaceOnUse"><path d="M22 0H0V22" fill="none" stroke="#ffffff" strokeOpacity=".07" /></pattern></defs>
          <rect width="220" height="230" fill="#18252e" /><rect width="220" height="230" fill="url(#ct-grid)" />
          <g transform="translate(110 116)" fill="none" stroke="#f8fafc">
            {[78, 66, 53, 40, 27].map((r, i) => <ellipse key={r} rx={r} ry={r * .85} strokeOpacity={.2 + i * .12} transform={`rotate(${i * 15})`} />)}
            <path d="M-67-45L55 65M-56 62L48-69M-78 0H78" strokeOpacity=".15" />
          </g>
          <path d="M25 30h18M25 30v18M195 30h-18M195 30v18M25 200h18M25 200v-18M195 200h-18M195 200v-18" fill="none" stroke="#ef4444" />
        </svg>
        <div className="ct-frame__caption"><span>Scanned data</span><span>.tif</span></div>
      </div>
      <div className="ct-frame ct-frame--output" data-art-float>
        <div className="ct-frame__heading"><span><UiIcon name="model" size={16} /> Frame interpolation</span><span className="ct-frame__dots" aria-hidden="true"><i /><i /><i /></span></div>
        <svg className="ct-frame__volume" viewBox="0 0 260 270" aria-hidden="true">
          <defs><linearGradient id="ct-volume-fill" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#fecaca" /><stop offset="1" stopColor="#b91c1c" /></linearGradient></defs>
          <path d="M15 70l115-55 115 55v133l-115 55-115-55z" fill="#fff1f2" />
          <g stroke="#fecaca" strokeWidth="1" fill="none"><path d="M15 70l115 56 115-56M130 126v132" /><path d="M43 56l115 57v132M73 41l115 58v131M103 27l115 57v132M15 106l115 56 115-56M15 142l115 56 115-56M15 177l115 56 115-56" /></g>
          <g data-ct-volume transform="translate(130 141)">
            <path d="M-67-40L0-73l67 33v69L0 64l-67-35z" fill="url(#ct-volume-fill)" fillOpacity=".24" stroke="#b91c1c" strokeOpacity=".3" />
            {[-32, -16, 0, 16, 32].map((y, i) => <ellipse key={y} cx="0" cy={y} rx="59" ry="27" fill="#b91c1c" fillOpacity={.1 + i * .035} stroke="#b91c1c" strokeOpacity=".65" data-ct-slice />)}
            <ellipse cx="0" cy="0" rx="23" ry="11" fill="#b91c1c" fillOpacity=".75" data-ct-core />
          </g>
          <path d="M24 96l106 52 106-52" fill="none" stroke="#b91c1c" strokeWidth="2" data-ct-sweep />
        </svg>
        <div className="ct-frame__caption"><span><i aria-hidden="true" /> Reconstructed frame</span><span>t = 0.5</span></div>
      </div>
      <figcaption><UiIcon name="shield" size={16} /> Reproducible by design</figcaption>
    </figure>
  );
}
