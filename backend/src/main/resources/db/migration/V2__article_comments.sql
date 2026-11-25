create table fionova.article_comments (
  id bigint generated always as identity primary key,
  article_id text not null,
  author_id text not null,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index article_comments_article_id on fionova.article_comments (article_id, id desc);
alter table fionova.article_comments enable row level security;
revoke all on fionova.article_comments from public;
