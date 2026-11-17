-- Opcional: si Daniela quedó a medias con un factor TOTP, limpiarlo.
-- En Authentication → Users → Daniela también se puede borrar el factor a mano.

delete from auth.mfa_challenges
where factor_id in (
  select id from auth.mfa_factors
  where user_id = (select id from auth.users where lower(email) = 'danielac@blasco.com.ar')
);

delete from auth.mfa_factors
where user_id = (select id from auth.users where lower(email) = 'danielac@blasco.com.ar');
