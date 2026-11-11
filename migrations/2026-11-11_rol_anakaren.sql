-- Ana Karen Torres como editora del CX Dashboard (mismo perfil que Itzel y Johana).
-- Reversa: delete from legacy.cx_dashboard_roles where email = 'anakaren@grupoavantex.com';
insert into legacy.cx_dashboard_roles (email, rol, nota)
values ('anakaren@grupoavantex.com', 'editor', 'EDITOR_EMAILS en index.html')
on conflict (email) do update set rol = excluded.rol, nota = excluded.nota;
select email, rol from legacy.cx_dashboard_roles order by rol, email;
