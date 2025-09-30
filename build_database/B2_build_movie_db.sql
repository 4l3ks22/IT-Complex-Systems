-- Drop old tables if they exist
DROP TABLE IF EXISTS titles, versions, persons, episodes, principals, genres, title_genre,
participates_in_title, known_for_title, person_profession, professions,
title_directors, title_writers, ratings, title_extras, word_index CASCADE;

-- Create working copies
CREATE TABLE titles AS TABLE title_basics;
CREATE TABLE versions AS TABLE title_akas;
CREATE TABLE ratings AS TABLE title_ratings;
CREATE TABLE persons AS TABLE name_basics;
CREATE TABLE episodes AS TABLE title_episode;
CREATE TABLE participates_in_title AS TABLE title_principals;
CREATE TABLE genres (genre_id SERIAL PRIMARY KEY, genre VARCHAR(50) UNIQUE NOT NULL);
CREATE TABLE title_genre (tconst VARCHAR(50) NOT NULL, genre INT4);
CREATE TABLE word_index AS TABLE wi;

ALTER TABLE versions RENAME COLUMN titleid TO tconst;

-- Normalize known titles
CREATE TABLE known_for_title (nconst VARCHAR(20) NOT NULL, tconst VARCHAR(20) NOT NULL);

INSERT INTO known_for_title (nconst, tconst)
SELECT nconst, unnest(string_to_array(knownfortitles, ',')) AS tconst
FROM persons
WHERE knownfortitles IS NOT NULL;

DELETE FROM known_for_title k
WHERE NOT EXISTS (SELECT 1 FROM titles t WHERE t.tconst = k.tconst);

ALTER TABLE persons DROP COLUMN knownfortitles;

-- Normalize professions
CREATE TABLE professions (profession_id SERIAL PRIMARY KEY, profession VARCHAR(50) UNIQUE NOT NULL);

-- Insert professions from persons
INSERT INTO professions (profession)
SELECT DISTINCT unnest(string_to_array(primaryprofession, ','))
FROM persons
WHERE primaryprofession IS NOT NULL;

-- Insert professions from participates_in_title categories
INSERT INTO professions (profession)
SELECT DISTINCT category
FROM participates_in_title
WHERE category IS NOT NULL
  AND category NOT IN (SELECT profession FROM professions);

-- Ensure "self" profession exists
INSERT INTO professions (profession)
SELECT 'self'
WHERE NOT EXISTS (SELECT 1 FROM professions WHERE profession = 'self');

-- Create directors and writers
CREATE TABLE title_directors (tconst VARCHAR(20) NOT NULL, nconst VARCHAR(20) NOT NULL);
INSERT INTO title_directors (tconst, nconst)
SELECT tconst, unnest(string_to_array(directors, ',')) AS nconst
FROM title_crew
WHERE directors IS NOT NULL;

CREATE TABLE title_writers (tconst VARCHAR(20) NOT NULL, nconst VARCHAR(20) NOT NULL);
INSERT INTO title_writers (tconst, nconst)
SELECT tconst, unnest(string_to_array(writers, ',')) AS nconst
FROM title_crew
WHERE writers IS NOT NULL;

-- Remove invalid nconst from participates_in_title
DELETE FROM participates_in_title pit
WHERE NOT EXISTS (SELECT 1 FROM persons p WHERE p.nconst = pit.nconst);

-- Add surrogate PK and temporary category column
ALTER TABLE participates_in_title
ADD COLUMN participation_id SERIAL PRIMARY KEY;

-- Insert directors and writers into participates_in_title if missing
-- Directors
INSERT INTO participates_in_title (tconst, nconst, category, ordering)
SELECT td.tconst, td.nconst, 'director', NULL
FROM title_directors td
JOIN persons p ON p.nconst = td.nconst
LEFT JOIN participates_in_title pit
       ON pit.tconst = td.tconst AND pit.nconst = td.nconst
      AND pit.category = 'director' AND pit.ordering IS NULL
WHERE pit.nconst IS NULL;

-- Writers
INSERT INTO participates_in_title (tconst, nconst, category, ordering)
SELECT tw.tconst, tw.nconst, 'writer', NULL
FROM title_writers tw
JOIN persons p ON p.nconst = tw.nconst
LEFT JOIN participates_in_title pit
       ON pit.tconst = tw.tconst AND pit.nconst = tw.nconst
      AND pit.category = 'writer' AND pit.ordering IS NULL
WHERE pit.nconst IS NULL;

-- Map category -> profession_id
ALTER TABLE participates_in_title ADD COLUMN profession_id INT;

UPDATE participates_in_title AS pit
SET profession_id = p.profession_id
FROM professions AS p
WHERE pit.category = p.profession;

ALTER TABLE participates_in_title DROP COLUMN category;

-- Insert all remaining principals from title_principals
INSERT INTO participates_in_title (tconst, nconst, profession_id, ordering)
SELECT DISTINCT tp.tconst, tp.nconst, p.profession_id, tp.ordering
FROM title_principals tp
JOIN persons per ON per.nconst = tp.nconst
JOIN professions p ON p.profession = tp.category
LEFT JOIN participates_in_title pit
       ON pit.tconst = tp.tconst AND pit.nconst = tp.nconst
      AND pit.profession_id = p.profession_id
      AND pit.ordering IS NOT DISTINCT FROM tp.ordering
WHERE pit.nconst IS NULL;

-- Create person_profession table
CREATE TABLE person_profession (nconst VARCHAR(20) NOT NULL, profession_id INT);

-- Insert distinct pairs from participates_in_title
INSERT INTO person_profession (nconst, profession_id)
SELECT DISTINCT pit.nconst, pit.profession_id
FROM participates_in_title pit
WHERE pit.profession_id IS NOT NULL;

--️⃣ Insert genres
INSERT INTO title_genre (tconst, genre)
SELECT titles.tconst, g.genre_id
FROM titles
CROSS JOIN LATERAL unnest(string_to_array(titles.genres, ',')) AS genre_text
JOIN genres g ON g.genre = genre_text;

-- Drop redundant columns and tables
ALTER TABLE persons DROP COLUMN primaryprofession;
DROP TABLE title_directors;
DROP TABLE title_writers;

-- Create title_extras
CREATE TABLE title_extras(
    tconst VARCHAR(20),
    awards TEXT,
    poster VARCHAR(200),
    plot TEXT
);

INSERT INTO title_extras(tconst, awards, poster, plot)
SELECT omdb_data.tconst, omdb_data.awards, omdb_data.poster, omdb_data.plot
FROM omdb_data
JOIN titles ON omdb_data.tconst = titles.tconst;

-- Add constraints
ALTER TABLE persons ADD CONSTRAINT pk_nconst_namebasics PRIMARY KEY (nconst);
ALTER TABLE titles ADD CONSTRAINT pk_tconst_titlebasics PRIMARY KEY (tconst);
ALTER TABLE versions ADD CONSTRAINT pk_title_ordering PRIMARY KEY (tconst, ordering),
                        ADD CONSTRAINT fk_tconst_akas FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE;
ALTER TABLE episodes ADD CONSTRAINT pk_tconst_episode PRIMARY KEY (tconst),
                       ADD CONSTRAINT fk_tconst_episode FOREIGN KEY (parenttconst) REFERENCES titles(tconst) ON DELETE CASCADE;
ALTER TABLE ratings ADD CONSTRAINT pk_tconst_ratings PRIMARY KEY (tconst),
                      ADD CONSTRAINT fk_tconst_ratings FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE;

ALTER TABLE person_profession
  ADD CONSTRAINT pk_nconst_profession PRIMARY KEY (nconst, profession_id),
  ADD CONSTRAINT fk_nconst_profession FOREIGN KEY (nconst) REFERENCES persons(nconst) ON DELETE CASCADE,
  ADD CONSTRAINT fk_profession_id FOREIGN KEY (profession_id) REFERENCES professions(profession_id) ON DELETE CASCADE;
	
ALTER TABLE participates_in_title
  ADD CONSTRAINT unique_participation UNIQUE (tconst, nconst, profession_id, ordering),
  ADD CONSTRAINT fk_nconst_participates FOREIGN KEY (nconst) REFERENCES persons(nconst) ON DELETE CASCADE,
  ADD CONSTRAINT fk_profession_participates FOREIGN KEY (nconst, profession_id) REFERENCES person_profession(nconst, profession_id) ON DELETE CASCADE,
  ADD CONSTRAINT fk_tconst_participates FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE;

ALTER TABLE known_for_title
  ADD CONSTRAINT pk_nconst_tconst PRIMARY KEY (nconst, tconst),
  ADD CONSTRAINT fk_nconst_known_for_title FOREIGN KEY (nconst) REFERENCES persons(nconst) ON DELETE CASCADE,
  ADD CONSTRAINT fk_tconst_known_for_title FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE;

ALTER TABLE title_genre
  ADD CONSTRAINT pk_tconst_genre PRIMARY KEY (tconst, genre),
  ADD CONSTRAINT fk_tconst_genre FOREIGN KEY (tconst) REFERENCES titles(tconst),
  ADD CONSTRAINT fk_genre FOREIGN KEY (genre) REFERENCES genres(genre_id);

ALTER TABLE title_extras
  ADD CONSTRAINT fk_tconst_extras FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE;

ALTER TABLE word_index
  ADD CONSTRAINT pk_tconst_lexeme PRIMARY KEY (tconst, word, field),
  ADD CONSTRAINT fk_tconst_word_index FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE;