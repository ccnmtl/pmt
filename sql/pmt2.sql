--
-- PostgreSQL database dump
--

SET client_encoding = 'SQL_ASCII';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'Standard public schema';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = true;

--
-- Name: actual_times; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE actual_times (
    iid integer NOT NULL,
    resolver character varying(32) NOT NULL,
    actual_time interval DEFAULT '01:00:00'::interval,
    completed timestamp without time zone DEFAULT "timestamp"('now'::text)
);


ALTER TABLE public.actual_times OWNER TO anders;

--
-- Name: admin; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE "admin" (
    username character varying(32) NOT NULL
);


ALTER TABLE public."admin" OWNER TO anders;

--
-- Name: attachment; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE attachment (
    id integer NOT NULL,
    item_id integer NOT NULL,
    filename character varying(128),
    title character varying(128),
    "type" character varying(8),
    url character varying(256),
    description text,
    author character varying(32) NOT NULL,
    last_mod timestamp without time zone DEFAULT ('now'::text)::timestamp(6) with time zone
);


ALTER TABLE public.attachment OWNER TO anders;

--
-- Name: attachment_id_seq; Type: SEQUENCE; Schema: public; Owner: anders
--

CREATE SEQUENCE attachment_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.attachment_id_seq OWNER TO anders;

--
-- Name: attachment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anders
--

ALTER SEQUENCE attachment_id_seq OWNED BY attachment.id;


--
-- Name: clients; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE clients (
    client_id integer NOT NULL,
    lastname character varying(64),
    firstname character varying(64),
    title character varying(128),
    registration_date date DEFAULT ('now'::text)::date,
    department character varying(255),
    school character varying(255),
    add_affiliation character varying(255),
    phone character varying(32),
    email character varying(128),
    contact character varying(32),
    comments text,
    status character varying(16) DEFAULT 'active'::character varying
);


ALTER TABLE public.clients OWNER TO anders;

--
-- Name: clients_client_id_seq; Type: SEQUENCE; Schema: public; Owner: anders
--

CREATE SEQUENCE clients_client_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.clients_client_id_seq OWNER TO anders;

--
-- Name: clients_client_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anders
--

ALTER SEQUENCE clients_client_id_seq OWNED BY clients.client_id;


--
-- Name: comments; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE comments (
    cid integer DEFAULT nextval(('comments_s'::text)::regclass) NOT NULL,
    "comment" text NOT NULL,
    add_date_time timestamp without time zone DEFAULT "timestamp"('now'::text),
    username character varying(32) NOT NULL,
    item integer,
    event integer
);


ALTER TABLE public.comments OWNER TO anders;

--
-- Name: comments_s; Type: SEQUENCE; Schema: public; Owner: anders
--

CREATE SEQUENCE comments_s
    INCREMENT BY 1
    MAXVALUE 2147483647
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.comments_s OWNER TO anders;

--
-- Name: dependencies; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE dependencies (
    source integer NOT NULL,
    dest integer NOT NULL
);


ALTER TABLE public.dependencies OWNER TO anders;

--
-- Name: documents; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE documents (
    did integer DEFAULT nextval(('documents_did_seq'::text)::regclass) NOT NULL,
    pid integer NOT NULL,
    filename character varying(128),
    title character varying(128),
    "type" character varying(8),
    url character varying(256),
    description text,
    version character varying(16),
    author character varying(32) NOT NULL,
    last_mod timestamp without time zone DEFAULT "timestamp"('now'::text)
);


ALTER TABLE public.documents OWNER TO anders;

--
-- Name: documents_did_seq; Type: SEQUENCE; Schema: public; Owner: anders
--

CREATE SEQUENCE documents_did_seq
    INCREMENT BY 1
    MAXVALUE 2147483647
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.documents_did_seq OWNER TO anders;

--
-- Name: events; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE events (
    eid integer DEFAULT nextval(('events_s'::text)::regclass) NOT NULL,
    status character varying(32) NOT NULL,
    event_date_time timestamp without time zone DEFAULT "timestamp"('now'::text),
    item integer
);


ALTER TABLE public.events OWNER TO anders;

--
-- Name: events_s; Type: SEQUENCE; Schema: public; Owner: anders
--

CREATE SEQUENCE events_s
    INCREMENT BY 1
    MAXVALUE 2147483647
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.events_s OWNER TO anders;

--
-- Name: in_group; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE in_group (
    grp character varying(32),
    username character varying(32)
);


ALTER TABLE public.in_group OWNER TO anders;

--
-- Name: item_clients; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE item_clients (
    iid integer NOT NULL,
    client_id integer NOT NULL
);


ALTER TABLE public.item_clients OWNER TO anders;

--
-- Name: items; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE items (
    iid integer DEFAULT nextval(('items_s'::text)::regclass) NOT NULL,
    "type" character varying(12) DEFAULT 'bug'::character varying NOT NULL,
    "owner" character varying(32) NOT NULL,
    assigned_to character varying(32) NOT NULL,
    title character varying(255) NOT NULL,
    mid integer NOT NULL,
    status character varying(16) NOT NULL,
    description text,
    priority integer,
    r_status character varying(16),
    last_mod timestamp without time zone DEFAULT "timestamp"('now'::text),
    target_date date,
    estimated_time interval DEFAULT '01:00:00'::interval,
    url text DEFAULT ''::text,
    CONSTRAINT items_priority CHECK (((priority >= 0) AND (priority < 5))),
    CONSTRAINT items_status CHECK ((((((((status)::text = ('OPEN'::character varying)::text) OR ((status)::text = ('RESOLVED'::character varying)::text)) OR ((status)::text = ('VERIFIED'::character varying)::text)) OR ((status)::text = ('CLOSED'::character varying)::text)) OR ((status)::text = ('INPROGRESS'::character varying)::text)) OR ((status)::text = ('UNASSIGNED'::character varying)::text))),
    CONSTRAINT items_type CHECK (((("type")::text = ('bug'::character varying)::text) OR (("type")::text = ('action item'::character varying)::text)))
);


ALTER TABLE public.items OWNER TO anders;

--
-- Name: items_s; Type: SEQUENCE; Schema: public; Owner: anders
--

CREATE SEQUENCE items_s
    INCREMENT BY 1
    MAXVALUE 2147483647
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.items_s OWNER TO anders;

--
-- Name: keywords; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE keywords (
    keyword character varying(255) NOT NULL,
    iid integer NOT NULL
);


ALTER TABLE public.keywords OWNER TO anders;

--
-- Name: milestones; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE milestones (
    mid integer DEFAULT nextval(('milestones_s'::text)::regclass) NOT NULL,
    name character varying(255) NOT NULL,
    target_date date NOT NULL,
    pid integer NOT NULL,
    status character varying(8) DEFAULT 'OPEN'::character varying NOT NULL,
    description text,
    CONSTRAINT milestones_status CHECK (((((status)::text = ('OPEN'::character varying)::text) OR ((status)::text = ('WAIT'::character varying)::text)) OR ((status)::text = ('CLOSED'::character varying)::text)))
);


ALTER TABLE public.milestones OWNER TO anders;

--
-- Name: milestones_s; Type: SEQUENCE; Schema: public; Owner: anders
--

CREATE SEQUENCE milestones_s
    INCREMENT BY 1
    MAXVALUE 2147483647
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.milestones_s OWNER TO anders;

--
-- Name: nodes; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE nodes (
    nid integer DEFAULT nextval(('nodes_nid_seq'::text)::regclass) NOT NULL,
    subject character varying(256) DEFAULT ''::character varying,
    body text,
    author character varying(32) NOT NULL,
    reply_to integer,
    replies integer DEFAULT 0,
    "type" character(8) DEFAULT 'comment'::bpchar NOT NULL,
    overflow boolean DEFAULT false,
    added timestamp without time zone DEFAULT "timestamp"('now'::text) NOT NULL,
    modified timestamp without time zone DEFAULT "timestamp"('now'::text) NOT NULL,
    project integer
);


ALTER TABLE public.nodes OWNER TO anders;

--
-- Name: nodes_nid_seq; Type: SEQUENCE; Schema: public; Owner: anders
--

CREATE SEQUENCE nodes_nid_seq
    INCREMENT BY 1
    MAXVALUE 2147483647
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.nodes_nid_seq OWNER TO anders;

--
-- Name: notify; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE "notify" (
    iid integer NOT NULL,
    username character varying(32) NOT NULL
);


ALTER TABLE public."notify" OWNER TO anders;

--
-- Name: notify_project; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE notify_project (
    pid integer NOT NULL,
    username character varying(32) NOT NULL
);


ALTER TABLE public.notify_project OWNER TO anders;

--
-- Name: project_clients; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE project_clients (
    pid integer NOT NULL,
    client_id integer NOT NULL,
    "role" character varying(255)
);


ALTER TABLE public.project_clients OWNER TO anders;

--
-- Name: projects; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE projects (
    pid integer DEFAULT nextval(('projects_s'::text)::regclass) NOT NULL,
    name character varying(255) NOT NULL,
    pub_view boolean DEFAULT true,
    caretaker character varying(32) NOT NULL,
    description text,
    status character varying(16) DEFAULT 'planning'::character varying,
    "type" character varying(50),
    area character varying(100),
    url character varying(255),
    restricted character varying(10),
    approach character varying(50),
    info_url character varying(255),
    entry_rel boolean DEFAULT false,
    eval_url character varying(255),
    projnum integer,
    scale character varying(20),
    distrib character varying(20),
    poster boolean DEFAULT false,
    wiki_category character varying(256) DEFAULT ''::character varying
);


ALTER TABLE public.projects OWNER TO anders;

--
-- Name: projects_s; Type: SEQUENCE; Schema: public; Owner: anders
--

CREATE SEQUENCE projects_s
    INCREMENT BY 1
    MAXVALUE 2147483647
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.projects_s OWNER TO anders;

--
-- Name: users; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE users (
    username character varying(32) NOT NULL,
    fullname character varying(128),
    email character varying(32) NOT NULL,
    status character varying(16) DEFAULT 'active'::character varying,
    grp boolean DEFAULT false,
    "password" character varying(32) DEFAULT 'nopassword'::character varying,
    "type" text DEFAULT 'Staff'::text,
    title text DEFAULT ''::text,
    phone text DEFAULT ''::text,
    bio text DEFAULT ''::text,
    photo_url text DEFAULT ''::text,
    photo_width integer DEFAULT 0,
    photo_height integer DEFAULT 0,
    campus text DEFAULT 'Morningside'::text,
    building text DEFAULT ''::text,
    room text DEFAULT ''::text
);


ALTER TABLE public.users OWNER TO anders;

--
-- Name: works_on; Type: TABLE; Schema: public; Owner: anders; Tablespace: 
--

CREATE TABLE works_on (
    username character varying(32) NOT NULL,
    pid integer NOT NULL,
    auth character varying(16) DEFAULT 'guest'::character varying NOT NULL,
    CONSTRAINT works_on_auth CHECK (((((auth)::text = ('guest'::character varying)::text) OR ((auth)::text = ('developer'::character varying)::text)) OR ((auth)::text = ('manager'::character varying)::text)))
);


ALTER TABLE public.works_on OWNER TO anders;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anders
--

ALTER TABLE attachment ALTER COLUMN id SET DEFAULT nextval('attachment_id_seq'::regclass);


--
-- Name: client_id; Type: DEFAULT; Schema: public; Owner: anders
--

ALTER TABLE clients ALTER COLUMN client_id SET DEFAULT nextval('clients_client_id_seq'::regclass);


--
-- Name: admin_pkey; Type: CONSTRAINT; Schema: public; Owner: anders; Tablespace: 
--

ALTER TABLE ONLY "admin"
    ADD CONSTRAINT admin_pkey PRIMARY KEY (username);


--
-- Name: clients_pkey; Type: CONSTRAINT; Schema: public; Owner: anders; Tablespace: 
--

ALTER TABLE ONLY clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (client_id);


--
-- Name: comments_pkey; Type: CONSTRAINT; Schema: public; Owner: anders; Tablespace: 
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (cid);


--
-- Name: dependencies_pkey; Type: CONSTRAINT; Schema: public; Owner: anders; Tablespace: 
--

ALTER TABLE ONLY dependencies
    ADD CONSTRAINT dependencies_pkey PRIMARY KEY (source, dest);


--
-- Name: events_pkey; Type: CONSTRAINT; Schema: public; Owner: anders; Tablespace: 
--

ALTER TABLE ONLY events
    ADD CONSTRAINT events_pkey PRIMARY KEY (eid);


--
-- Name: items_pkey; Type: CONSTRAINT; Schema: public; Owner: anders; Tablespace: 
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_pkey PRIMARY KEY (iid);


--
-- Name: keywords_pkey; Type: CONSTRAINT; Schema: public; Owner: anders; Tablespace: 
--

ALTER TABLE ONLY keywords
    ADD CONSTRAINT keywords_pkey PRIMARY KEY (keyword, iid);


--
-- Name: milestones_pkey; Type: CONSTRAINT; Schema: public; Owner: anders; Tablespace: 
--

ALTER TABLE ONLY milestones
    ADD CONSTRAINT milestones_pkey PRIMARY KEY (mid);


--
-- Name: notify_pkey; Type: CONSTRAINT; Schema: public; Owner: anders; Tablespace: 
--

ALTER TABLE ONLY "notify"
    ADD CONSTRAINT notify_pkey PRIMARY KEY (iid, username);


--
-- Name: notify_project_pkey; Type: CONSTRAINT; Schema: public; Owner: anders; Tablespace: 
--

ALTER TABLE ONLY notify_project
    ADD CONSTRAINT notify_project_pkey PRIMARY KEY (pid, username);


--
-- Name: projects_pkey; Type: CONSTRAINT; Schema: public; Owner: anders; Tablespace: 
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (pid);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: anders; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (username);


--
-- Name: works_on_pkey; Type: CONSTRAINT; Schema: public; Owner: anders; Tablespace: 
--

ALTER TABLE ONLY works_on
    ADD CONSTRAINT works_on_pkey PRIMARY KEY (username, pid);


--
-- Name: documents_did_key; Type: INDEX; Schema: public; Owner: anders; Tablespace: 
--

CREATE UNIQUE INDEX documents_did_key ON documents USING btree (did);


--
-- Name: nodes_nid_key; Type: INDEX; Schema: public; Owner: anders; Tablespace: 
--

CREATE UNIQUE INDEX nodes_nid_key ON nodes USING btree (nid);


--
-- Name: users_idx; Type: INDEX; Schema: public; Owner: anders; Tablespace: 
--

CREATE INDEX users_idx ON users USING hash (username);


--
-- Name: RI_ConstraintTrigger_740982; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON users
    FROM projects
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_del"('<unnamed>', 'projects', 'users', 'UNSPECIFIED', 'caretaker', 'username');


--
-- Name: RI_ConstraintTrigger_740983; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON users
    FROM projects
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'projects', 'users', 'UNSPECIFIED', 'caretaker', 'username');


--
-- Name: RI_ConstraintTrigger_740984; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON users
    FROM works_on
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'works_on', 'users', 'UNSPECIFIED', 'username', 'username');


--
-- Name: RI_ConstraintTrigger_740985; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON users
    FROM works_on
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'works_on', 'users', 'UNSPECIFIED', 'username', 'username');


--
-- Name: RI_ConstraintTrigger_740986; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON users
    FROM items
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_del"('<unnamed>', 'items', 'users', 'UNSPECIFIED', 'owner', 'username');


--
-- Name: RI_ConstraintTrigger_740987; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON users
    FROM items
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'items', 'users', 'UNSPECIFIED', 'owner', 'username');


--
-- Name: RI_ConstraintTrigger_740988; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON users
    FROM items
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_del"('<unnamed>', 'items', 'users', 'UNSPECIFIED', 'assigned_to', 'username');


--
-- Name: RI_ConstraintTrigger_740989; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON users
    FROM items
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'items', 'users', 'UNSPECIFIED', 'assigned_to', 'username');


--
-- Name: RI_ConstraintTrigger_740990; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON users
    FROM "notify"
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'notify', 'users', 'UNSPECIFIED', 'username', 'username');


--
-- Name: RI_ConstraintTrigger_740991; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON users
    FROM "notify"
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'notify', 'users', 'UNSPECIFIED', 'username', 'username');


--
-- Name: RI_ConstraintTrigger_740992; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON users
    FROM "admin"
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_del"('<unnamed>', 'admin', 'users', 'UNSPECIFIED', 'username', 'username');


--
-- Name: RI_ConstraintTrigger_740993; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON users
    FROM "admin"
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'admin', 'users', 'UNSPECIFIED', 'username', 'username');


--
-- Name: RI_ConstraintTrigger_740994; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON users
    FROM documents
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'documents', 'users', 'UNSPECIFIED', 'author', 'username');


--
-- Name: RI_ConstraintTrigger_740995; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON users
    FROM documents
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'documents', 'users', 'UNSPECIFIED', 'author', 'username');


--
-- Name: RI_ConstraintTrigger_740996; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON users
    FROM nodes
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'nodes', 'users', 'UNSPECIFIED', 'author', 'username');


--
-- Name: RI_ConstraintTrigger_740997; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON users
    FROM nodes
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'nodes', 'users', 'UNSPECIFIED', 'author', 'username');


--
-- Name: RI_ConstraintTrigger_740998; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON users
    FROM actual_times
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'actual_times', 'users', 'UNSPECIFIED', 'resolver', 'username');


--
-- Name: RI_ConstraintTrigger_740999; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON users
    FROM actual_times
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'actual_times', 'users', 'UNSPECIFIED', 'resolver', 'username');


--
-- Name: RI_ConstraintTrigger_741000; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON users
    FROM in_group
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'in_group', 'users', 'UNSPECIFIED', 'grp', 'username');


--
-- Name: RI_ConstraintTrigger_741001; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON users
    FROM in_group
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'in_group', 'users', 'UNSPECIFIED', 'grp', 'username');


--
-- Name: RI_ConstraintTrigger_741002; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON users
    FROM in_group
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'in_group', 'users', 'UNSPECIFIED', 'username', 'username');


--
-- Name: RI_ConstraintTrigger_741003; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON users
    FROM in_group
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'in_group', 'users', 'UNSPECIFIED', 'username', 'username');


--
-- Name: RI_ConstraintTrigger_741004; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON projects
    FROM users
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'projects', 'users', 'UNSPECIFIED', 'caretaker', 'username');


--
-- Name: RI_ConstraintTrigger_741005; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON projects
    FROM milestones
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'milestones', 'projects', 'UNSPECIFIED', 'pid', 'pid');


--
-- Name: RI_ConstraintTrigger_741006; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON projects
    FROM milestones
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'milestones', 'projects', 'UNSPECIFIED', 'pid', 'pid');


--
-- Name: RI_ConstraintTrigger_741007; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON projects
    FROM works_on
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'works_on', 'projects', 'UNSPECIFIED', 'pid', 'pid');


--
-- Name: RI_ConstraintTrigger_741008; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON projects
    FROM works_on
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'works_on', 'projects', 'UNSPECIFIED', 'pid', 'pid');


--
-- Name: RI_ConstraintTrigger_741009; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON projects
    FROM documents
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'documents', 'projects', 'UNSPECIFIED', 'pid', 'pid');


--
-- Name: RI_ConstraintTrigger_741010; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON projects
    FROM documents
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'documents', 'projects', 'UNSPECIFIED', 'pid', 'pid');


--
-- Name: RI_ConstraintTrigger_741011; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON projects
    FROM nodes
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'nodes', 'projects', 'UNSPECIFIED', 'project', 'pid');


--
-- Name: RI_ConstraintTrigger_741012; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON projects
    FROM nodes
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'nodes', 'projects', 'UNSPECIFIED', 'project', 'pid');


--
-- Name: RI_ConstraintTrigger_741013; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON milestones
    FROM projects
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'milestones', 'projects', 'UNSPECIFIED', 'pid', 'pid');


--
-- Name: RI_ConstraintTrigger_741014; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON milestones
    FROM items
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_del"('<unnamed>', 'items', 'milestones', 'UNSPECIFIED', 'mid', 'mid');


--
-- Name: RI_ConstraintTrigger_741015; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON milestones
    FROM items
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'items', 'milestones', 'UNSPECIFIED', 'mid', 'mid');


--
-- Name: RI_ConstraintTrigger_741016; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON works_on
    FROM users
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'works_on', 'users', 'UNSPECIFIED', 'username', 'username');


--
-- Name: RI_ConstraintTrigger_741017; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON works_on
    FROM projects
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'works_on', 'projects', 'UNSPECIFIED', 'pid', 'pid');


--
-- Name: RI_ConstraintTrigger_741018; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON items
    FROM milestones
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'items', 'milestones', 'UNSPECIFIED', 'mid', 'mid');


--
-- Name: RI_ConstraintTrigger_741019; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON items
    FROM users
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'items', 'users', 'UNSPECIFIED', 'owner', 'username');


--
-- Name: RI_ConstraintTrigger_741020; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON items
    FROM users
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'items', 'users', 'UNSPECIFIED', 'assigned_to', 'username');


--
-- Name: RI_ConstraintTrigger_741021; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON items
    FROM keywords
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'keywords', 'items', 'UNSPECIFIED', 'iid', 'iid');


--
-- Name: RI_ConstraintTrigger_741022; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON items
    FROM keywords
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'keywords', 'items', 'UNSPECIFIED', 'iid', 'iid');


--
-- Name: RI_ConstraintTrigger_741023; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON items
    FROM dependencies
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_del"('<unnamed>', 'dependencies', 'items', 'UNSPECIFIED', 'source', 'iid');


--
-- Name: RI_ConstraintTrigger_741024; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON items
    FROM dependencies
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'dependencies', 'items', 'UNSPECIFIED', 'source', 'iid');


--
-- Name: RI_ConstraintTrigger_741025; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON items
    FROM dependencies
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_del"('<unnamed>', 'dependencies', 'items', 'UNSPECIFIED', 'dest', 'iid');


--
-- Name: RI_ConstraintTrigger_741026; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON items
    FROM dependencies
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'dependencies', 'items', 'UNSPECIFIED', 'dest', 'iid');


--
-- Name: RI_ConstraintTrigger_741027; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON items
    FROM events
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'events', 'items', 'UNSPECIFIED', 'item', 'iid');


--
-- Name: RI_ConstraintTrigger_741028; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON items
    FROM events
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'events', 'items', 'UNSPECIFIED', 'item', 'iid');


--
-- Name: RI_ConstraintTrigger_741029; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON items
    FROM comments
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'comments', 'items', 'UNSPECIFIED', 'item', 'iid');


--
-- Name: RI_ConstraintTrigger_741030; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON items
    FROM comments
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'comments', 'items', 'UNSPECIFIED', 'item', 'iid');


--
-- Name: RI_ConstraintTrigger_741031; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON items
    FROM actual_times
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'actual_times', 'items', 'UNSPECIFIED', 'iid', 'iid');


--
-- Name: RI_ConstraintTrigger_741032; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON items
    FROM actual_times
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'actual_times', 'items', 'UNSPECIFIED', 'iid', 'iid');


--
-- Name: RI_ConstraintTrigger_741033; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON keywords
    FROM items
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'keywords', 'items', 'UNSPECIFIED', 'iid', 'iid');


--
-- Name: RI_ConstraintTrigger_741034; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON "notify"
    FROM users
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'notify', 'users', 'UNSPECIFIED', 'username', 'username');


--
-- Name: RI_ConstraintTrigger_741035; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON dependencies
    FROM items
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'dependencies', 'items', 'UNSPECIFIED', 'source', 'iid');


--
-- Name: RI_ConstraintTrigger_741036; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON dependencies
    FROM items
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'dependencies', 'items', 'UNSPECIFIED', 'dest', 'iid');


--
-- Name: RI_ConstraintTrigger_741037; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON events
    FROM items
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'events', 'items', 'UNSPECIFIED', 'item', 'iid');


--
-- Name: RI_ConstraintTrigger_741038; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER DELETE ON events
    FROM comments
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_cascade_del"('<unnamed>', 'comments', 'events', 'UNSPECIFIED', 'event', 'eid');


--
-- Name: RI_ConstraintTrigger_741039; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER UPDATE ON events
    FROM comments
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_noaction_upd"('<unnamed>', 'comments', 'events', 'UNSPECIFIED', 'event', 'eid');


--
-- Name: RI_ConstraintTrigger_741040; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON comments
    FROM items
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'comments', 'items', 'UNSPECIFIED', 'item', 'iid');


--
-- Name: RI_ConstraintTrigger_741041; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON comments
    FROM events
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'comments', 'events', 'UNSPECIFIED', 'event', 'eid');


--
-- Name: RI_ConstraintTrigger_741042; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON "admin"
    FROM users
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'admin', 'users', 'UNSPECIFIED', 'username', 'username');


--
-- Name: RI_ConstraintTrigger_741043; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON nodes
    FROM users
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'nodes', 'users', 'UNSPECIFIED', 'author', 'username');


--
-- Name: RI_ConstraintTrigger_741044; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON actual_times
    FROM items
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'actual_times', 'items', 'UNSPECIFIED', 'iid', 'iid');


--
-- Name: RI_ConstraintTrigger_741045; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON actual_times
    FROM users
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'actual_times', 'users', 'UNSPECIFIED', 'resolver', 'username');


--
-- Name: RI_ConstraintTrigger_741046; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON in_group
    FROM users
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'in_group', 'users', 'UNSPECIFIED', 'grp', 'username');


--
-- Name: RI_ConstraintTrigger_741047; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON in_group
    FROM users
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'in_group', 'users', 'UNSPECIFIED', 'username', 'username');


--
-- Name: RI_ConstraintTrigger_741048; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON documents
    FROM projects
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'documents', 'projects', 'UNSPECIFIED', 'pid', 'pid');


--
-- Name: RI_ConstraintTrigger_741049; Type: TRIGGER; Schema: public; Owner: anders
--

CREATE CONSTRAINT TRIGGER "<unnamed>"
    AFTER INSERT OR UPDATE ON documents
    FROM users
    NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE PROCEDURE "RI_FKey_check_ins"('<unnamed>', 'documents', 'users', 'UNSPECIFIED', 'author', 'username');


--
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: anders
--

ALTER TABLE ONLY clients
    ADD CONSTRAINT "$1" FOREIGN KEY (contact) REFERENCES users(username) ON DELETE CASCADE;


--
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: anders
--

ALTER TABLE ONLY project_clients
    ADD CONSTRAINT "$1" FOREIGN KEY (pid) REFERENCES projects(pid) ON DELETE CASCADE;


--
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: anders
--

ALTER TABLE ONLY item_clients
    ADD CONSTRAINT "$1" FOREIGN KEY (iid) REFERENCES items(iid) ON DELETE CASCADE;


--
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: anders
--

ALTER TABLE ONLY notify_project
    ADD CONSTRAINT "$1" FOREIGN KEY (pid) REFERENCES projects(pid) ON DELETE CASCADE;


--
-- Name: $2; Type: FK CONSTRAINT; Schema: public; Owner: anders
--

ALTER TABLE ONLY project_clients
    ADD CONSTRAINT "$2" FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE;


--
-- Name: $2; Type: FK CONSTRAINT; Schema: public; Owner: anders
--

ALTER TABLE ONLY item_clients
    ADD CONSTRAINT "$2" FOREIGN KEY (client_id) REFERENCES clients(client_id);


--
-- Name: $2; Type: FK CONSTRAINT; Schema: public; Owner: anders
--

ALTER TABLE ONLY notify_project
    ADD CONSTRAINT "$2" FOREIGN KEY (username) REFERENCES users(username) ON DELETE CASCADE;


--
-- Name: attachment_author_fkey; Type: FK CONSTRAINT; Schema: public; Owner: anders
--

ALTER TABLE ONLY attachment
    ADD CONSTRAINT attachment_author_fkey FOREIGN KEY (author) REFERENCES users(username) ON DELETE CASCADE;


--
-- Name: attachment_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: anders
--

ALTER TABLE ONLY attachment
    ADD CONSTRAINT attachment_item_id_fkey FOREIGN KEY (item_id) REFERENCES items(iid) ON DELETE CASCADE;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

