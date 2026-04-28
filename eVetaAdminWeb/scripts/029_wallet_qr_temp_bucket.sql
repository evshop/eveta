-- 029_wallet_qr_temp_bucket.sql
-- Bucket temporal privado para imágenes QR de recarga.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'wallet-qr-temp',
  'wallet-qr-temp',
  false,
  5242880,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
