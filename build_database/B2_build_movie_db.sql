  DROP TABLE IF EXISTS titles CASCADE;
  DROP TABLE IF EXISTS versions CASCADE;
  DROP TABLE IF EXISTS persons CASCADE;
  DROP TABLE IF EXISTS episodes CASCADE;
  DROP TABLE IF EXISTS principals CASCADE;
  DROP TABLE IF EXISTS genres CASCADE;
  DROP TABLE IF EXISTS title_genre CASCADE;
  DROP TABLE IF EXISTS participates_in_title CASCADE;
  DROP TABLE IF EXISTS known_for_title CASCADE;
  DROP TABLE IF EXISTS person_profession CASCADE;
  DROP TABLE IF EXISTS professions CASCADE;
  DROP TABLE IF EXISTS title_directors CASCADE;
  DROP TABLE IF EXISTS title_writers CASCADE;
  DROP TABLE IF EXISTS ratings CASCADE;
  DROP TABLE IF EXISTS title_extras CASCADE;
  DROP TABLE IF EXISTS word_index CASCADE;

--Create copies of the original tables in order to safely work with the data.
  CREATE TABLE titles AS TABLE title_basics;
  CREATE TABLE versions AS TABLE title_akas;
  CREATE TABLE ratings AS TABLE title_ratings;
  CREATE TABLE persons AS TABLE name_basics;
  CREATE TABLE episodes AS TABLE title_episode;
  CREATE TABLE principals AS TABLE title_principals;
  CREATE TABLE genres (genre_id SERIAL, genre VARCHAR (50) NOT NULL UNIQUE);
  CREATE TABLE title_genre (tconst VARCHAR (50) NOT NULL, genre INT4);
  CREATE TABLE word_index AS TABLE wi;
  
  ALTER TABLE versions RENAME COLUMN titleid TO tconst;

/* To follow proper normalization and not violate "First Normal Form" 1NF, name_basics table has some columns in form of csv - needs to be normalized -> create separate tables for both professions and known titles instead,
	 then will drop the 2 redundant columns */

-- Creating table for titles that persons are known for.
  CREATE TABLE known_for_title (nconst VARCHAR (20) NOT NULL, tconst VARCHAR (20) NOT NULL);

--Separating csv value in individual tconsy values, and insert nconst and tconst inside the new "known_for_title" table
  INSERT INTO known_for_title (nconst, tconst)
  SELECT
      nconst,
      unnest(string_to_array(knownfortitles, ',')) AS tconst
  FROM persons
  WHERE knownfortitles IS NOT NULL;

--Delete rows where the title is not in the database and it still assigned as a title that person is known for
  DELETE
  FROM
    known_for_title k
  WHERE
    NOT EXISTS (SELECT 1 FROM titles t WHERE t.tconst = k.tconst);

--Drop redundant column
  ALTER TABLE persons DROP COLUMN knownfortitles;
   
  CREATE TABLE professions (profession_id SERIAL PRIMARY KEY, profession VARCHAR (50) NOT NULL);
  
--Creating professions table to categorize all the possible professions   
  INSERT INTO professions (profession) SELECT DISTINCT
    UNNEST(string_to_array(primaryprofession, ',')) AS profession
  FROM
    persons
  WHERE
    primaryprofession IS NOT NULL;

--Creating table for each person's professions
  CREATE TABLE person_profession (nconst VARCHAR (20) NOT NULL, profession_id INT);

--Inserting all persons and their professions into a table
  INSERT INTO person_profession (nconst, profession_id) SELECT
    nconst,
    profession_id
  FROM
    persons
    CROSS JOIN LATERAL UNNEST(string_to_array(persons.primaryprofession, ',')) AS prof_name
    JOIN professions ON professions.profession = TRIM(prof_name);

  
--Creating title_directors and title_writers tables from title_crew and dropping the redundant table
  CREATE TABLE title_directors (tconst VARCHAR (20) NOT NULL, nconst VARCHAR (20) NOT NULL);

  INSERT INTO title_directors (tconst, nconst) SELECT
    tconst,
    UNNEST(string_to_array(directors, ',')) AS nconst
  FROM
    title_crew
  WHERE
    directors IS NOT NULL;
  
  CREATE TABLE title_writers (tconst VARCHAR (20) NOT NULL, nconst VARCHAR (20) NOT NULL);
  
  INSERT INTO title_writers (tconst, nconst) SELECT
    tconst,
    UNNEST(string_to_array(writers, ',')) AS nconst
  FROM
    title_crew
  WHERE
    writers IS NOT NULL;
  

--Creating table for titles person participates in and their profession there
  CREATE TABLE participates_in_title (
      participate_id SERIAL,
      nconst VARCHAR(20) NOT NULL,
      ordering INT,
      tconst VARCHAR(20) NOT NULL,
      profession_id INT 
  );

  INSERT INTO participates_in_title (nconst, ordering, tconst, profession_id)
  SELECT
     principals.nconst, ordering, tconst, profession_id
  FROM principals JOIN person_profession ON principals.nconst = person_profession.nconst 
  WHERE category IS NOT NULL;

  INSERT INTO participates_in_title (nconst, tconst, profession_id)
  SELECT nconst, tconst, profession_id
  FROM (
      SELECT directors.nconst, directors.tconst, professions.profession_id
      FROM title_directors directors
      JOIN professions ON professions.profession = 'director'

      UNION ALL

      SELECT writers.nconst, writers.tconst, professions.profession_id
      FROM title_writers writers
      JOIN professions ON professions.profession = 'writer'
  ) AS combined
  WHERE NOT EXISTS (
      SELECT 1
      FROM participates_in_title
      WHERE participates_in_title.nconst = combined.nconst
        AND participates_in_title.tconst = combined.tconst
        AND participates_in_title.profession_id = combined.profession_id
  );

  INSERT INTO genres (genre)
  SELECT DISTINCT genre 
  FROM titles,
       unnest(string_to_array(titles.genres, ',')) AS genre;


  INSERT INTO title_genre (tconst, genre)
  SELECT
      titles.tconst,
      genres.genre_id
  FROM titles 
  CROSS JOIN LATERAL unnest(string_to_array(titles.genres, ',')) AS genre_text
  JOIN genres 
    ON genres.genre = trim(genre_text);

--Drop column and tables
  ALTER TABLE persons
  DROP COLUMN primaryprofession;
  DROP TABLE title_directors;
  DROP TABLE title_writers;

--Creating table for media and plots from OMDB_data
  CREATE TABLE title_extras(
    tconst VARCHAR(20),
    awards TEXT,
    poster VARCHAR(200),
    plot TEXT 
    );

    
  INSERT INTO title_extras(tconst, awards, poster, plot)
  SELECT omdb_data.tconst, omdb_data.awards, omdb_data.poster, omdb_data.plot 
  FROM omdb_data JOIN titles ON omdb_data.tconst = titles.tconst;

--Adding primary and foreign keys to tables - do it at the end
  ALTER TABLE persons ADD CONSTRAINT pk_nconst_namebasics PRIMARY KEY (nconst); -- name constant ID
  ALTER TABLE titles ADD CONSTRAINT pk_tconst_titlebasics PRIMARY KEY (tconst); -- title constant ID
  ALTER TABLE versions ADD CONSTRAINT pk_title_ordering PRIMARY KEY (tconst, ordering), 
                         ADD CONSTRAINT fk_tconst_akas FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE; 
                         
  ALTER TABLE episodes ADD CONSTRAINT pk_tconst_episode PRIMARY KEY (tconst), 
                            ADD CONSTRAINT fk_tconst_episode FOREIGN KEY (parenttconst) REFERENCES titles(tconst) ON DELETE CASCADE; -- parenttconts refers to tconst in title basics
																																																																				 -- (episodes are supposed to be tconst themselves to be searchable)
  ALTER TABLE principals ADD CONSTRAINT pk_tconst_ordering_nconst PRIMARY KEY (tconst, ordering, nconst, category); 
  ALTER TABLE ratings ADD CONSTRAINT pk__tconst_ratings PRIMARY KEY (tconst),
                            ADD CONSTRAINT fk_tconst_ratings FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE;
                            
                            
ALTER TABLE person_profession
  ADD CONSTRAINT pk_nconst_profession PRIMARY KEY (nconst, profession_id),
  ADD CONSTRAINT fk_nconst_profession FOREIGN KEY (nconst)
    REFERENCES persons(nconst) ON DELETE CASCADE,
  ADD CONSTRAINT fk_profession_id FOREIGN KEY (profession_id)
    REFERENCES professions(profession_id) ON DELETE CASCADE; 

  ALTER TABLE known_for_title ADD CONSTRAINT pk_nconst_tconst PRIMARY KEY (nconst, tconst),
                              ADD CONSTRAINT fk_nconst_known_for_title FOREIGN KEY (nconst) REFERENCES persons(nconst) ON DELETE CASCADE,
                              ADD CONSTRAINT fk_tconst_known_for_title FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE;
  ALTER TABLE genres ADD CONSTRAINT pk_genres PRIMARY KEY (genre_id);
  
ALTER TABLE title_genre
  ADD CONSTRAINT pk_tconst_genre PRIMARY KEY (tconst, genre),
  ADD CONSTRAINT fk_tconst_genre
    FOREIGN KEY (tconst) REFERENCES titles(tconst),
  ADD CONSTRAINT fk_genre
    FOREIGN KEY (genre)  REFERENCES genres(genre_id);
  
ALTER TABLE title_extras
  ADD CONSTRAINT fk_tconst_extras FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE; 

ALTER TABLE word_index
  ADD CONSTRAINT pk_tconst_lexeme PRIMARY KEY (tconst, word, field),
  ADD CONSTRAINT fk_tconst_word_index FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE; 
