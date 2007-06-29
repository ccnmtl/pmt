CREATE SEQUENCE projects_s     START 001;
CREATE SEQUENCE milestones_s   START 001;
CREATE SEQUENCE items_s        START 001;
CREATE SEQUENCE events_s       START 001;
CREATE SEQUENCE comments_s     START 001;

CREATE TABLE users (
       username varchar(32) PRIMARY KEY,
       fullname varchar(128),
       email varchar(32) NOT NULL,
       status varchar(16) DEFAULT 'active',
       grp boolean DEFAULT 'false',
       password varchar(32) NOT NULL DEFAULT 'nopassword'
);

CREATE TABLE in_group (
	grp varchar(32),
	username varchar(32),
	FOREIGN KEY (grp) REFERENCES users (username) 
	ON DELETE CASCADE,
	FOREIGN KEY (username) REFERENCES users (username) 
	ON DELETE CASCADE
);

CREATE TABLE admin (
       username varchar(32) PRIMARY KEY,
       FOREIGN KEY (username) REFERENCES users (username)
);

CREATE TABLE projects (
       pid integer PRIMARY KEY DEFAULT NEXTVAL('projects_s'),
       name varchar(255) NOT NULL,
       pub_view boolean DEFAULT true,
       caretaker varchar(32) NOT NULL,
       description TEXT,
       status varchar(16) DEFAULT 'planning',
	type varchar(50) DEFAULT 'Project',
	area varchar(100) DEFAULT 'n/a',
	url varchar(255),
	restricted varchar(10),
	approach varchar(50),
	info_url varchar(255),
	entry_rel boolean DEFAULT 'false',
	eval_url varchar(255),
	projnum integer,
	scale varchar(20),
	distrib varchar(20),
	poster boolean DEFAULT 'false',
        wiki_category character varying(256),
        FOREIGN KEY (caretaker) REFERENCES users (username)
);

CREATE TABLE milestones (
       mid integer PRIMARY KEY DEFAULT NEXTVAL('milestones_s'),
       name varchar(255) NOT NULL,
       target_date DATE NOT NULL,
       pid integer NOT NULL,
       status varchar(8) NOT NULL DEFAULT 'OPEN'
        CHECK (status = 'OPEN' OR status = 'WAIT' OR status = 'CLOSED'),
       description TEXT,
       FOREIGN KEY (pid) REFERENCES projects (pid)
        ON DELETE CASCADE
);

CREATE TABLE works_on (
       username varchar(32) NOT NULL,
       pid integer NOT NULL,
       auth varchar(16) NOT NULL DEFAULT 'guest'
	 CHECK (auth = 'guest' OR auth = 'developer' OR auth = 'manager'),
       PRIMARY KEY (username,pid),
       FOREIGN KEY (username) REFERENCES users (username)
         ON DELETE CASCADE,
       FOREIGN KEY (pid) REFERENCES projects (pid)
         ON DELETE CASCADE
);

CREATE TABLE items (
       iid integer PRIMARY KEY DEFAULT NEXTVAL('items_s'),
       type varchar(12) NOT NULL DEFAULT ('bug')
         CHECK (type = 'bug' OR type = 'action item'),
       owner varchar(32) NOT NULL,
       assigned_to varchar(32) NOT NULL,
       title varchar(255) NOT NULL,
       mid integer NOT NULL,
       url varchar(255),
       status varchar(16) NOT NULL
         CHECK (status = 'OPEN' OR status = 'RESOLVED' OR status = 'VERIFIED'
	        OR status = 'CLOSED' OR status = 'INPROGRESS' 
		OR status = 'UNASSIGNED'),
       description text,
       priority integer
         CHECK (priority >= 0 AND priority < 5),
       r_status varchar(16) DEFAULT NULL,
       last_mod TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
       target_date DATE,
       estimated_time INTERVAL DEFAULT '01:00',
       FOREIGN KEY (mid) REFERENCES milestones (mid),
       FOREIGN KEY (owner)     REFERENCES users (username),
       FOREIGN KEY (assigned_to) REFERENCES users (username)
);

CREATE TABLE actual_times (
	iid integer NOT NULL, 
	resolver varchar(32) NOT NULL,
	actual_time INTERVAL DEFAULT '01:00',
	completed TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (iid) REFERENCES items (iid)
	ON DELETE CASCADE,
	FOREIGN KEY (resolver) REFERENCES users (username)
	ON DELETE CASCADE
);


CREATE TABLE notify (
       iid integer NOT NULL,
       username varchar(32) NOT NULL,
       PRIMARY KEY (iid,username),
       FOREIGN KEY (username)     REFERENCES users (username) 
         ON DELETE CASCADE
);

CREATE TABLE notify_project (
       pid integer NOT NULL,
       username varchar(32) NOT NULL,
       PRIMARY KEY (pid,username),
       FOREIGN KEY (username)     REFERENCES users (username) 
         ON DELETE CASCADE
);

CREATE TABLE events (
       eid integer PRIMARY KEY DEFAULT NEXTVAL('events_s'),
       status varchar(32) NOT NULL,
       event_date_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
       item integer,
       FOREIGN KEY (item) REFERENCES items (iid)
         ON DELETE CASCADE
);

CREATE TABLE comments (
       cid integer PRIMARY KEY DEFAULT NEXTVAL('comments_s'),
       comment TEXT NOT NULL,
       add_date_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
       username varchar(32) NOT NULL,
       item integer,
       event integer,
       FOREIGN KEY (item) REFERENCES items (iid)
         ON DELETE CASCADE,
       FOREIGN KEY (event) REFERENCES events (eid)
         ON DELETE CASCADE
);

CREATE TABLE nodes (
	nid serial,
	subject VARCHAR(256) DEFAULT '',
	body TEXT,
	author VARCHAR(32) NOT NULL,
	reply_to integer,	
	replies integer DEFAULT 0,
	type char(8) NOT NULL DEFAULT ('comment'),
	overflow bool DEFAULT 'f',
	added TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	project integer,
	FOREIGN KEY (author) REFERENCES users (username)
	  ON DELETE CASCADE,
	FOREIGN KEY (project) REFERENCES projects (pid)
 	  ON DELETE CASCADE
);

CREATE TABLE documents (
	did serial,
	pid integer not null,
	filename varchar(128),
	title varchar(128),
	type varchar(8),
	url varchar(256),
	description text,
	version varchar(16),
	author varchar(32) not null,
	last_mod timestamp default CURRENT_TIMESTAMP,
	FOREIGN KEY (pid) REFERENCES projects (pid)
	  ON DELETE CASCADE,
	FOREIGN KEY (author) REFERENCES users (username)
	  ON DELETE CASCADE
);

CREATE TABLE attachment (
       id serial,
       item_id integer not null,
       
       filename varchar(128),
       title varchar(128),
       type varchar(8),
       url varchar(256),
       description text,
       author varchar(32) not null,
       last_mod timestamp default CURRENT_TIMESTAMP,
       FOREIGN KEY (item_id) REFERENCES items (iid)
	  ON DELETE CASCADE,
	FOREIGN KEY (author) REFERENCES users (username)
	  ON DELETE CASCADE

);


CREATE TABLE clients (
	client_id serial primary key,
	lastname varchar(64),
	firstname varchar(64),
	title varchar(128),
	registration_date date default CURRENT_DATE,
	department varchar(255),
	school varchar(255),
	add_affiliation varchar(255),
	phone varchar(32),
	email varchar(128),
	contact varchar(32),
	comments text,
	status varchar(16) default 'active',
	foreign key (contact) references users (username)
	  on delete cascade
);

CREATE TABLE project_clients (
	pid integer not null,
	client_id integer not null,
	role varchar(255),
	foreign key (pid) references projects (pid)
	  on delete cascade,
	foreign key (client_id) references clients (client_id)
	  on delete cascade
);

CREATE TABLE item_clients (
	iid integer not null,
	client_id integer not null,
	foreign key (iid) references items (iid)
		on delete cascade,
	foreign key (client_id) references clients (client_id)
		on delete cascade
);
