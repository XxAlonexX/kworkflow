CREATE TABLE IF NOT EXISTS tags(
	id INTEGER PRIMARY KEY,
	tag VARCHAR(32) UNIQUE
);

CREATE TABLE IF NOT EXISTS pomodoro(
	tag_id INTEGER REFERENCES tags(id),
	dt_start DATETIME NOT NULL,
	dt_end DATETIME NOT NULL,
	descript VARCHAR(512)
);

CREATE TABLE IF NOT EXISTS statistic(
	label VARCHAR(32),
	dt_start DATETIME NOT NULL,
	dt_end DATETIME NOT NULL
);
