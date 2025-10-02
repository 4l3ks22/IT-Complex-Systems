-- Dropping tables to rebuild the database
DROP TABLE IF EXISTS titles, versions, persons, episodes, principals, genres, title_genre,
participates_in_title,crew, known_for_title, person_profession, professions,
title_directors, title_writers, ratings, title_extras, word_index CASCADE;

-- Creating copies of original tables that will be used to build our functioning database - not touching originals in order to be able to rebuild
CREATE TABLE titles AS TABLE title_basics;
CREATE TABLE versions AS TABLE title_akas;
CREATE TABLE ratings AS TABLE title_ratings;
CREATE TABLE crew AS TABLE title_crew;
CREATE TABLE persons AS TABLE name_basics;
CREATE TABLE episodes AS TABLE title_episode;
CREATE TABLE participates_in_title AS TABLE title_principals;
CREATE TABLE word_index AS TABLE wi;

ALTER TABLE versions RENAME COLUMN titleid TO tconst;

-- Creating table to normalize perons table that has column for movies that people are known for in csv format (text) which violates db normalization
CREATE TABLE known_for_title (nconst VARCHAR(20) NOT NULL, tconst VARCHAR(20) NOT NULL);

INSERT INTO known_for_title (nconst, tconst)
SELECT nconst, unnest(string_to_array(knownfortitles, ',')) AS tconst
FROM persons
WHERE knownfortitles IS NOT NULL;

-- There are tconst values in known_for_titles that do not exist in titles table
-- Making sure to remove titles that are not in our main titles table (not existent anymore or missing)
DELETE FROM known_for_title k
WHERE NOT EXISTS (SELECT 1 FROM titles t WHERE t.tconst = k.tconst);

-- Dropping the redundant column from persons
ALTER TABLE persons DROP COLUMN knownfortitles;

-- Creating table professions to put all possible professions into to keep them organized 
CREATE TABLE professions (profession_id SERIAL PRIMARY KEY, profession VARCHAR(50) UNIQUE NOT NULL);

-- Insert professions from persons primaryprofession
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

-- There are nconst values in participates_in_title that do not exist in persons table
-- Making sure to remove people that are not in our main persons database to match (as otherwise we would have nconst for people, who we don't have names of)
DELETE FROM participates_in_title pit
WHERE NOT EXISTS (SELECT 1 FROM persons p WHERE p.nconst = pit.nconst);

-- Create directors and writers - the crew table has both in csv format, we decided to normalize them into separate tables
CREATE TABLE title_directors (tconst VARCHAR(20) NOT NULL, nconst VARCHAR(20) NOT NULL);
INSERT INTO title_directors (tconst, nconst)
SELECT tconst, unnest(string_to_array(directors, ',')) AS nconst
FROM crew
WHERE directors IS NOT NULL;

CREATE TABLE title_writers (tconst VARCHAR(20) NOT NULL, nconst VARCHAR(20) NOT NULL);
INSERT INTO title_writers (tconst, nconst)
SELECT tconst, unnest(string_to_array(writers, ',')) AS nconst
FROM crew
 WHERE writers IS NOT NULL;


-- To make looking for participates easier, quicker and keep persons' professions in a separate table for normalization purpose - we implemented a surrogate primary key that is an ID, which is unique for each participant, movie, ordering specifically
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

-- Adding profession_id for each persons' profession instead of keeping professions (category) there (dropped after)
ALTER TABLE participates_in_title ADD COLUMN profession_id INT;

UPDATE participates_in_title AS pit
SET profession_id = p.profession_id
FROM professions AS p
WHERE pit.category = p.profession;

-- To make sure people have assigned only proper professions they do in future movies (actor will not be allowed to be assigned other job if not specified as his profession), 
-- we implemented a table where we can see all of each person's professions 
CREATE TABLE person_profession (nconst VARCHAR(20) NOT NULL, profession_id INT);

-- Insert distinct pairs from participates_in_title
INSERT INTO person_profession (nconst, profession_id)
SELECT DISTINCT pit.nconst, pit.profession_id
FROM participates_in_title pit
WHERE pit.profession_id IS NOT NULL;

-- Creating genres table to keep track of all distinct possible genres of titles with unique IDs
CREATE TABLE genres (genre_id SERIAL PRIMARY KEY, genre VARCHAR(50) UNIQUE NOT NULL);

INSERT INTO genres(genre)
SELECT DISTINCT genre
FROM titles
CROSS JOIN LATERAL unnest(string_to_array(genres, ',')) AS genre
WHERE genres IS NOT NULL;

-- Creating title genre table to assign genres for each movie 
CREATE TABLE title_genre (tconst VARCHAR(50) NOT NULL, genre INT4);

INSERT INTO title_genre (tconst, genre)
SELECT titles.tconst, g.genre_id
FROM titles
CROSS JOIN LATERAL unnest(string_to_array(titles.genres, ',')) AS genre_text
JOIN genres g ON g.genre = genre_text;

-- Drop redundant columns and tables
ALTER TABLE persons DROP COLUMN primaryprofession;
DROP TABLE title_directors;
DROP TABLE title_writers;

-- Create title_extras table for poster, awards and plot for each movie from omdb_data
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