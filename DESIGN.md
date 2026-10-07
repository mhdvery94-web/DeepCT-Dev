# 🎨 Design System & UI/UX Guidelines

> **Status: panduan design system.** Token warna, tipografi dan komponen di
> sini adalah acuan. Nilai yang benar-benar dipakai ada di
> `fe/lib/theme/app_theme.dart`; kalau keduanya berbeda, kode yang menang.
> Breakpoint responsif yang aktual didokumentasikan di
> [fe/README.md](fe/README.md).
> Tampilan web produksi pada Vercel telah diterima pada 1 Oktober 2026 untuk
> landing page, login, dashboard researcher, pembatasan navigasi berdasarkan
> peran, dan sign-out. Skenario serta hasil pengamatan ada di
> [USER_ACCEPTANCE_TESTING.md](USER_ACCEPTANCE_TESTING.md).

---


Dokumentasi lengkap design system untuk Platform Analisis Citra Neutron CT BRIN.

---

## 🎯 Design Philosophy

Platform ini dirancang dengan prinsip **Institutional Excellence** - kombinasi antara rigor akademis formal dengan estetika modern data science. Design mencerminkan:

- **Authority**: Kesan institusional yang kuat dan terpercaya
- **Accuracy**: Visual yang presisi dan terstruktur
- **Professionalism**: Tampilan yang serius dan tidak main-main
- **Accessibility**: Mudah digunakan oleh peneliti dari berbagai background

**Inspired by**: 
- CERN Open Data Portal
- MIT MITRE Dashboards
- Government Research Portals

---

## 🎨 Color Palette

### Primary Colors

```css
/* BRIN Red - Primary Brand Color */
--color-primary: #B91C1C;        /* Buttons, active states, CTA */
--color-primary-hover: #991B1B;  /* Hover states */
--color-primary-light: #FEF2F2;  /* Light backgrounds */
--color-primary-dark: #7F1D1D;   /* Dark accents */
```

### Neutral Colors

```css
/* Backgrounds */
--color-background: #F8FAFC;     /* Page background (Cool slate off-white) */
--color-surface: #FFFFFF;        /* Cards, modals, navigation */

/* Text */
--color-text: #0F172A;           /* Deep midnight blue - Headings, primary text */
--color-muted: #64748B;          /* Steel gray - Secondary text, inactive tabs */

/* Borders */
--color-border: #E2E8F0;         /* Subtle borders, dividers */
--color-border-dark: #CBD5E1;    /* Stronger borders */
```

### Semantic Colors

```css
/* Success */
--color-success: #059669;        /* Completed status, high confidence */
--color-success-light: #D1FAE5;  /* Success backgrounds */

/* Error */
--color-error: #DC2626;          /* Failed status, validation errors */
--color-error-light: #FEE2E2;    /* Error backgrounds */

/* Warning */
--color-warning: #F59E0B;        /* Warnings, pending status */
--color-warning-light: #FEF3C7;  /* Warning backgrounds */

/* Info */
--color-accent: #0369A1;         /* Academic blue - Informational highlights */
--color-accent-light: #E0F2FE;   /* Info backgrounds */
```

### Color Usage Guidelines

| Element | Color | Usage |
|---------|-------|-------|
| Primary CTA | `--color-primary` | Login button, submit forms, main actions |
| Secondary CTA | `--color-surface` with border | Cancel, back, optional actions |
| Text Headings | `--color-text` | All h1-h6 elements |
| Body Text | `--color-text` | Paragraphs, descriptions |
| Labels | `--color-muted` | Form labels, captions |
| Success | `--color-success` | Completed predictions, success messages |
| Error | `--color-error` | Failed predictions, form errors |
| Warning | `--color-warning` | Expiring files, attention needed |

---

## 📝 Typography

### Font Families

```css
/* Headings - Serif untuk kesan akademis */
--font-heading: 'Lora', serif;
font-weight: 700;
letter-spacing: -0.02em;

/* Body Text - Sans-serif untuk legibility */
--font-body: 'IBM Plex Sans', sans-serif;
font-weight: 400;
letter-spacing: 0;

/* Monospace - Untuk kode, data, metrics */
--font-mono: 'IBM Plex Mono', monospace;
```

### Type Scale

```css
/* Headings */
--text-5xl: 48px;    /* Hero titles */
--text-4xl: 36px;    /* Page titles */
--text-3xl: 30px;    /* Section titles */
--text-2xl: 24px;    /* Card titles */
--text-xl: 20px;     /* Subsection titles */
--text-lg: 18px;     /* Large body text */

/* Body */
--text-base: 16px;   /* Default body text */
--text-sm: 14px;     /* Small text, buttons */
--text-xs: 13px;     /* Captions, labels */
--text-2xs: 12px;    /* Tiny text, metadata */

/* Line Heights */
--leading-tight: 1.25;   /* Headings */
--leading-normal: 1.5;   /* Body text */
--leading-relaxed: 1.75; /* Paragraphs */
```

### Typography Examples

```html
<!-- Page Title -->
<h1 class="font-heading text-4xl font-bold text-text tracking-tight">
  Advancing Indonesian Research through Deep Learning
</h1>

<!-- Section Title with Divider -->
<h2 class="font-heading text-3xl font-bold text-text">
  About the Models
</h2>
<div class="w-10 h-1 bg-primary mt-2 mb-6"></div>

<!-- Body Text -->
<p class="font-body text-base text-text leading-relaxed">
  The BRIN Research Portal provides access to state-of-the-art deep learning models...
</p>

<!-- Caption / Label -->
<label class="text-xs font-semibold text-muted uppercase tracking-wider">
  Email Address
</label>

<!-- Data / Metrics -->
<span class="font-mono text-lg text-text">
  94.2%
</span>
```

---

## 🧱 Layout & Spacing

### Spacing System (8px base)

```css
--spacing-1: 8px;
--spacing-2: 16px;
--spacing-3: 24px;
--spacing-4: 32px;
--spacing-5: 40px;
--spacing-6: 48px;
--spacing-8: 64px;
--spacing-12: 96px;
--spacing-16: 128px;
```

### Container Widths

```css
--container-sm: 640px;   /* Mobile content */
--container-md: 768px;   /* Tablet content */
--container-lg: 1024px;  /* Desktop content */
--container-xl: 1200px;  /* Max content width */
```

### Grid System

```css
/* 12-column grid */
.grid-12 {
  display: grid;
  grid-template-columns: repeat(12, 1fr);
  gap: var(--spacing-3);
}

/* Responsive breakpoints */
@media (max-width: 768px) {
  .grid-12 {
    grid-template-columns: repeat(4, 1fr); /* 4 columns mobile */
  }
}

@media (min-width: 769px) and (max-width: 1024px) {
  .grid-12 {
    grid-template-columns: repeat(8, 1fr); /* 8 columns tablet */
  }
}
```

---

## 🎯 Design Tokens

### Border Radius

```css
/* Flat design - minimal rounding */
--radius-none: 0px;      /* Default untuk semua elements */
--radius-sm: 0px;        /* Buttons, inputs */
--radius-md: 0px;        /* Cards */
--radius-lg: 0px;        /* Modals */
--radius-full: 0px;      /* Avatars (use clip-path instead) */
```

**Note**: Platform ini menggunakan **sharp corners** (0px radius) untuk semua elements sesuai desain flat, technical, paper-like aesthetic.

### Shadows

```css
/* Flat design - NO shadows */
--shadow-none: none;

/* All elements use borders instead of shadows */
box-shadow: none !important;
```

**Note**: Gunakan `border: 1px solid var(--color-border)` untuk pemisahan visual, BUKAN shadows.

### Borders

```css
--border-thin: 1px solid var(--color-border);
--border-medium: 2px solid var(--color-border);
--border-thick: 4px solid var(--color-primary);

/* Border usage */
.card {
  border: var(--border-thin);
}

.active-indicator {
  border-left: var(--border-thick);
}
```

---

## 🧩 Component Library

### Buttons

#### Primary Button
```html
<button class="
  px-6 py-3 
  bg-primary hover:bg-primary-hover 
  text-white text-sm font-semibold 
  uppercase tracking-wider 
  transition-colors
">
  Submit Request
</button>
```

#### Secondary Button
```html
<button class="
  px-6 py-3 
  bg-surface border border-text 
  text-text text-sm font-semibold 
  uppercase tracking-wider 
  hover:bg-background 
  transition-colors
">
  Cancel
</button>
```

#### Disabled Button
```html
<button class="
  px-6 py-3 
  bg-border text-muted 
  text-sm font-semibold 
  uppercase tracking-wider 
  cursor-not-allowed
" disabled>
  Processing...
</button>
```

---

### Form Inputs

#### Text Input
```html
<div class="flex flex-col gap-2">
  <label class="text-xs font-semibold text-muted uppercase tracking-wider">
    Email Address
  </label>
  <input 
    type="email"
    class="
      h-12 px-4 
      border border-muted bg-surface 
      text-base text-text 
      focus:border-text focus:outline-none 
      transition-colors
    "
    placeholder="name@brin.go.id"
  />
</div>
```

#### Input with Error
```html
<div class="flex flex-col gap-2">
  <label class="text-xs font-semibold text-muted uppercase tracking-wider">
    Password
  </label>
  <input 
    type="password"
    class="
      h-12 px-4 
      border-2 border-error bg-surface 
      text-base text-text 
      focus:border-error focus:outline-none
    "
  />
  <span class="text-xs text-error">
    Password must be at least 8 characters
  </span>
</div>
```

#### File Upload / Dropzone
```html
<div class="
  h-64 
  border-2 border-dashed border-muted 
  bg-background 
  flex flex-col items-center justify-center 
  hover:border-primary hover:bg-surface 
  transition-colors cursor-pointer
">
  <svg class="w-12 h-12 text-muted mb-4">...</svg>
  <p class="text-sm text-text font-medium">
    Drag files here or browse
  </p>
  <p class="text-xs text-muted mt-1">
    Supports .tif files up to 50MB
  </p>
</div>
```

---

### Cards

#### Basic Card
```html
<div class="
  bg-surface 
  border border-border 
  p-6
">
  <h3 class="font-heading text-xl font-bold text-text mb-3">
    Card Title
  </h3>
  <p class="text-sm text-muted leading-relaxed">
    Card content goes here...
  </p>
</div>
```

#### Metric Card
```html
<div class="
  bg-surface 
  border border-border 
  p-5
">
  <p class="text-xs font-semibold text-muted uppercase tracking-wider mb-2">
    Processing Time
  </p>
  <p class="font-mono text-3xl font-bold text-text">
    3.45s
  </p>
</div>
```

#### Clickable Card (Hover State)
```html
<div class="
  bg-surface 
  border border-border 
  p-6 
  hover:bg-background hover:border-border-dark 
  transition-colors cursor-pointer
">
  <!-- Card content -->
</div>
```

---

### Status Badges

```html
<!-- Online / Success -->
<div class="flex items-center gap-2">
  <div class="w-2 h-2 rounded-full bg-success"></div>
  <span class="text-sm text-muted font-medium">Online</span>
</div>

<!-- Offline / Error -->
<div class="flex items-center gap-2">
  <div class="w-2 h-2 rounded-full bg-error animate-pulse"></div>
  <span class="text-sm text-error font-bold">Offline</span>
</div>

<!-- Pending / Warning -->
<div class="flex items-center gap-2">
  <div class="w-2 h-2 rounded-full bg-warning"></div>
  <span class="text-sm text-muted font-medium">Pending</span>
</div>
```

---

### Navigation

#### Sidebar Navigation
```html
<aside class="w-64 bg-surface border-r border-border h-screen">
  <!-- Logo -->
  <div class="p-6 border-b border-border">
    <h1 class="font-heading font-bold text-2xl text-text">
      BRIN<span class="text-primary">.</span>
    </h1>
  </div>
  
  <!-- Nav Items -->
  <nav class="py-4 px-3">
    <!-- Active Item -->
    <a class="
      flex items-center gap-3 px-3 py-2.5 
      bg-background border-l-4 border-primary 
      text-text font-semibold
    ">
      <span class="material-symbols-outlined">analytics</span>
      <span class="text-sm">Prediction Results</span>
    </a>
    
    <!-- Inactive Item -->
    <a class="
      flex items-center gap-3 px-3 py-2.5 
      text-muted 
      hover:bg-background 
      transition-colors
    ">
      <span class="material-symbols-outlined">history</span>
      <span class="text-sm">History</span>
    </a>
  </nav>
</aside>
```

#### Top Header Navigation
```html
<header class="
  h-16 bg-surface border-b border-border 
  flex items-center justify-between 
  px-10
">
  <!-- Logo -->
  <div class="flex items-center gap-4">
    <svg class="w-6 h-6 text-primary">...</svg>
    <h2 class="font-heading text-xl font-bold text-text">BRIN</h2>
  </div>
  
  <!-- Nav Links -->
  <nav class="flex items-center gap-8">
    <a class="text-sm font-semibold text-text hover:text-primary transition-colors">
      Home
    </a>
    <a class="text-sm font-semibold text-text hover:text-primary transition-colors">
      About
    </a>
  </nav>
  
  <!-- CTA -->
  <button class="px-6 py-2.5 bg-primary hover:bg-primary-hover text-white text-sm font-semibold uppercase">
    Login
  </button>
</header>
```

---

### Data Tables

```html
<div class="border border-border">
  <table class="w-full">
    <thead class="bg-background">
      <tr>
        <th class="px-4 py-3 text-left text-xs font-semibold text-muted uppercase tracking-wider">
          Name
        </th>
        <th class="px-4 py-3 text-left text-xs font-semibold text-muted uppercase tracking-wider">
          Status
        </th>
        <th class="px-4 py-3 text-left text-xs font-semibold text-muted uppercase tracking-wider">
          Actions
        </th>
      </tr>
    </thead>
    <tbody class="bg-surface">
      <tr class="border-b border-border hover:bg-background transition-colors">
        <td class="px-4 py-4 text-sm text-text font-medium">
          Dr. Sample Researcher
        </td>
        <td class="px-4 py-4">
          <div class="flex items-center gap-2">
            <div class="w-2 h-2 rounded-full bg-success"></div>
            <span class="text-sm text-muted">Active</span>
          </div>
        </td>
        <td class="px-4 py-4">
          <button class="text-sm text-primary hover:underline">
            Edit
          </button>
        </td>
      </tr>
    </tbody>
  </table>
</div>
```

---

### Progress Bars

#### Loading Bar
```html
<div class="w-full h-1 bg-border relative overflow-hidden">
  <div class="absolute h-full bg-primary animate-pulse" style="width: 65%;"></div>
</div>
```

#### Confidence Score Bar
```html
<div class="w-full h-3 bg-border relative overflow-hidden">
  <div class="absolute h-full bg-success transition-all duration-1000" style="width: 94.2%;"></div>
  <!-- Threshold Marker -->
  <div class="absolute h-full w-0.5 bg-text opacity-30" style="left: 90%;"></div>
</div>
<div class="flex justify-between text-xs text-muted font-mono mt-1">
  <span>0%</span>
  <span>Threshold: 90%</span>
  <span>100%</span>
</div>
```

---

### Modals / Dialogs

```html
<!-- Backdrop -->
<div class="fixed inset-0 bg-text bg-opacity-50 flex items-center justify-center p-4 z-50">
  <!-- Modal -->
  <div class="bg-surface border border-border max-w-lg w-full">
    <!-- Header -->
    <div class="border-b border-border px-6 py-4">
      <h3 class="font-heading text-2xl font-bold text-text">
        Confirm Delete
      </h3>
    </div>
    
    <!-- Content -->
    <div class="px-6 py-5">
      <p class="text-base text-text leading-relaxed">
        Are you sure you want to delete this prediction? This action cannot be undone.
      </p>
    </div>
    
    <!-- Actions -->
    <div class="border-t border-border px-6 py-4 flex justify-end gap-3">
      <button class="px-4 py-2 bg-surface border border-text text-text text-sm font-semibold uppercase hover:bg-background">
        Cancel
      </button>
      <button class="px-4 py-2 bg-error text-white text-sm font-semibold uppercase hover:bg-error-dark">
        Delete
      </button>
    </div>
  </div>
</div>
```

---

### Toast / Snackbar Notifications

```html
<!-- Success Toast -->
<div class="
  fixed bottom-6 right-6 
  bg-surface border-l-4 border-success 
  shadow-lg p-4 
  flex items-center gap-3 
  max-w-md
">
  <span class="material-symbols-outlined text-success">check_circle</span>
  <div>
    <p class="text-sm font-semibold text-text">Success</p>
    <p class="text-xs text-muted">Prediction completed successfully</p>
  </div>
</div>

<!-- Error Toast -->
<div class="
  fixed bottom-6 right-6 
  bg-surface border-l-4 border-error 
  shadow-lg p-4 
  flex items-center gap-3 
  max-w-md
">
  <span class="material-symbols-outlined text-error">error</span>
  <div>
    <p class="text-sm font-semibold text-text">Error</p>
    <p class="text-xs text-muted">Failed to upload file</p>
  </div>
</div>
```

---

## 📱 Responsive Design

### Breakpoints

```css
/* Mobile First Approach */
--breakpoint-sm: 640px;   /* Small devices */
--breakpoint-md: 768px;   /* Tablets */
--breakpoint-lg: 1024px;  /* Laptops */
--breakpoint-xl: 1200px;  /* Desktops */
```

### Responsive Patterns

#### Hide/Show Elements
```html
<!-- Hide on mobile, show on desktop -->
<div class="hidden md:block">Desktop content</div>

<!-- Show on mobile, hide on desktop -->
<div class="block md:hidden">Mobile content</div>
```

#### Grid Stacking
```html
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
  <!-- 1 col mobile, 2 cols tablet, 3 cols desktop -->
</div>
```

#### Sidebar Behavior
- **Desktop**: Fixed sidebar (240px width)
- **Tablet**: Collapsed sidebar (80px width, icons only)
- **Mobile**: Drawer menu (hamburger button)

---

## 🌗 Dark Mode (Future)

Color variables untuk dark mode:

```css
@media (prefers-color-scheme: dark) {
  :root {
    --color-background: #0F172A;
    --color-surface: #1E293B;
    --color-text: #F1F5F9;
    --color-muted: #94A3B8;
    --color-border: #334155;
  }
}
```

---

## ♿ Accessibility Guidelines

### Focus States
```css
/* Keyboard navigation */
button:focus,
input:focus,
a:focus {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}
```

### Color Contrast
- Text on background: WCAG AAA (7:1 ratio minimum)
- Interactive elements: WCAG AA (4.5:1 ratio minimum)

### ARIA Labels
```html
<button aria-label="Close dialog">
  <span class="material-symbols-outlined">close</span>
</button>

<input 
  type="email" 
  aria-label="Email address" 
  aria-required="true"
  aria-invalid="false"
/>
```

### Screen Reader Support
- Semantic HTML elements (nav, main, aside, header, footer)
- Alt text untuk semua images
- aria-live regions untuk dynamic content

---

## 🎭 Animations & Transitions

### Transition Speeds
```css
--transition-fast: 150ms;     /* Hover effects */
--transition-normal: 300ms;   /* Default transitions */
--transition-slow: 500ms;     /* Page transitions */
```

### Common Transitions
```css
/* Hover effects */
.button {
  transition: background-color var(--transition-fast) ease;
}

/* Loading spinner */
@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

/* Fade in */
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

/* Pulse (offline indicator) */
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}
```

---

## 📐 Icon System

### Material Symbols Outlined
```html
<!-- Import from Google Fonts -->
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined" rel="stylesheet">

<!-- Usage -->
<span class="material-symbols-outlined">analytics</span>
<span class="material-symbols-outlined">upload_file</span>
<span class="material-symbols-outlined">settings</span>
```

### Icon Sizes
```css
--icon-sm: 16px;   /* Inline icons */
--icon-md: 24px;   /* Default icons */
--icon-lg: 32px;   /* Feature icons */
--icon-xl: 48px;   /* Hero icons */
```

---

## 🖼️ Logo & Branding Assets

### BRIN Logo Usage

Tersedia di folder `/images`:
- `BRIN_Logo.ico` - Icon format
- `BRIN.png` - Full logo PNG
- `DL_neutron_xray_CT.ico` - App icon

**Guidelines**:
- Minimum size: 32px (icon), 120px (full logo)
- Clear space: 16px padding pada semua sisi
- Tidak boleh diubah proporsi atau warna
- Gunakan pada background putih atau sangat terang

---

## 📏 Design Checklist

Sebelum finalisasi screen, pastikan:

- [ ] Sharp corners (0px radius) semua elements
- [ ] Tidak ada shadows (borders only)
- [ ] Font Lora untuk headings
- [ ] Font IBM Plex Sans untuk body
- [ ] BRIN Red (#B91C1C) untuk primary actions
- [ ] 1px solid borders untuk separasi
- [ ] Text color contrast memenuhi WCAG AA
- [ ] Responsive untuk mobile, tablet, desktop
- [ ] Hover states untuk semua interactive elements
- [ ] Focus states untuk keyboard navigation
- [ ] Loading states untuk async actions
- [ ] Error states untuk forms

---

**Last Updated**: August 13, 2026  
**Version**: 1.0.0  
**Design System**: Institutional Excellence (Modern & Formal)
