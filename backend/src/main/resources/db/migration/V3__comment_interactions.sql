alter table fionova.article_comments
  add column if not exists parent_id bigint references fionova.article_comments(id) on delete cascade;

create index if not exists article_comments_thread on fionova.article_comments (article_id, parent_id, id desc);
create index if not exists article_comments_parent on fionova.article_comments (parent_id);

create table if not exists fionova.article_comment_likes (
  comment_id bigint not null references fionova.article_comments(id) on delete cascade,
  user_id text not null,
  primary key (comment_id, user_id)
);
alter table fionova.article_comment_likes enable row level security;
revoke all on fionova.article_comment_likes from public;
