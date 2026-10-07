export type UserRole = "admin" | "user";

export type DeepCtUser = {
  id: number;
  name: string;
  email: string;
  phone?: string | null;
  role: UserRole;
  is_active: boolean;
  avatar_url?: string | null;
  must_change_password: boolean;
  last_login_at?: string | null;
  created_at?: string | null;
};

export type NewsPost = {
  id: number;
  title: string;
  summary: string;
  body?: string | null;
  has_image: boolean;
  image_url?: string | null;
  has_video: boolean;
  video_url?: string | null;
  video_size_bytes?: number | null;
  published_at?: string | null;
  sort_order?: number;
};

export type UserStats = {
  activities_total: number;
  activities_today: number;
  analyses_total: number;
  analyses_by_status: Record<string, number>;
  models_online: number;
  models_total: number;
};

export type ApiEnvelope<T> = {
  success: boolean;
  message?: string;
  data: T;
  errors?: Record<string, string[]>;
};
