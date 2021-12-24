--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.24
-- Dumped by pg_dump version 9.6.24

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: amdb; Type: DATABASE; Schema: -; Owner: dba
--

CREATE DATABASE amdb WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'C.UTF-8' LC_CTYPE = 'C.UTF-8';


ALTER DATABASE amdb OWNER TO dba;

\connect amdb

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: album_id_seq; Type: SEQUENCE; Schema: public; Owner: amdb
--

CREATE SEQUENCE public.album_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.album_id_seq OWNER TO amdb;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: album; Type: TABLE; Schema: public; Owner: amdb
--

CREATE TABLE public.album (
    id integer DEFAULT nextval('public.album_id_seq'::regclass) NOT NULL,
    name character varying(64) NOT NULL,
    year numeric(4,0),
    performer integer NOT NULL,
    comment character varying
);


ALTER TABLE public.album OWNER TO amdb;

--
-- Name: condition_id_seq; Type: SEQUENCE; Schema: public; Owner: amdb
--

CREATE SEQUENCE public.condition_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.condition_id_seq OWNER TO amdb;

--
-- Name: condition; Type: TABLE; Schema: public; Owner: amdb
--

CREATE TABLE public.condition (
    id integer DEFAULT nextval('public.condition_id_seq'::regclass) NOT NULL,
    name character varying(64) NOT NULL,
    comment character varying
);


ALTER TABLE public.condition OWNER TO amdb;

--
-- Name: media_id_seq; Type: SEQUENCE; Schema: public; Owner: amdb
--

CREATE SEQUENCE public.media_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.media_id_seq OWNER TO amdb;

--
-- Name: media; Type: TABLE; Schema: public; Owner: amdb
--

CREATE TABLE public.media (
    id integer DEFAULT nextval('public.media_id_seq'::regclass) NOT NULL,
    number numeric(10,0) NOT NULL,
    type integer NOT NULL,
    album integer NOT NULL,
    comment character varying,
    "timestamp" timestamp without time zone DEFAULT now(),
    status integer DEFAULT 1,
    condition integer DEFAULT 1
);


ALTER TABLE public.media OWNER TO amdb;

--
-- Name: performer_id_seq; Type: SEQUENCE; Schema: public; Owner: amdb
--

CREATE SEQUENCE public.performer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.performer_id_seq OWNER TO amdb;

--
-- Name: performer; Type: TABLE; Schema: public; Owner: amdb
--

CREATE TABLE public.performer (
    id integer DEFAULT nextval('public.performer_id_seq'::regclass) NOT NULL,
    name character varying(64) NOT NULL,
    comment character varying
);


ALTER TABLE public.performer OWNER TO amdb;

--
-- Name: status_id_seq; Type: SEQUENCE; Schema: public; Owner: amdb
--

CREATE SEQUENCE public.status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.status_id_seq OWNER TO amdb;

--
-- Name: status; Type: TABLE; Schema: public; Owner: amdb
--

CREATE TABLE public.status (
    id integer DEFAULT nextval('public.status_id_seq'::regclass) NOT NULL,
    name character varying(64) NOT NULL,
    comment character varying
);


ALTER TABLE public.status OWNER TO amdb;

--
-- Name: type_id_seq; Type: SEQUENCE; Schema: public; Owner: amdb
--

CREATE SEQUENCE public.type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.type_id_seq OWNER TO amdb;

--
-- Name: type; Type: TABLE; Schema: public; Owner: amdb
--

CREATE TABLE public.type (
    id integer DEFAULT nextval('public.type_id_seq'::regclass) NOT NULL,
    name character varying(16) NOT NULL,
    comment character varying
);


ALTER TABLE public.type OWNER TO amdb;

--
-- Name: viewalbum; Type: VIEW; Schema: public; Owner: amdb
--

CREATE VIEW public.viewalbum AS
 SELECT a.name AS artist,
    b.id,
    b.name AS album,
    b.year
   FROM public.performer a,
    public.album b
  WHERE (b.performer = a.id)
  ORDER BY b.name;


ALTER TABLE public.viewalbum OWNER TO amdb;

--
-- Name: viewallalbum; Type: VIEW; Schema: public; Owner: amdb
--

CREATE VIEW public.viewallalbum AS
 SELECT a.name AS performer,
    b.id,
    b.name AS album,
    b.year,
    b.comment
   FROM public.performer a,
    public.album b
  WHERE (b.performer = a.id);


ALTER TABLE public.viewallalbum OWNER TO amdb;

--
-- Name: viewallmedia; Type: VIEW; Schema: public; Owner: amdb
--

CREATE VIEW public.viewallmedia AS
 SELECT c.id,
    c.number,
    d.name AS type,
    a.name AS performer,
    b.name AS album,
    c.comment,
    b.year,
    c."timestamp",
    a.comment AS commentp,
    b.comment AS commenda,
    e.name AS status,
    f.name AS condition
   FROM public.performer a,
    public.album b,
    public.media c,
    public.type d,
    public.status e,
    public.condition f
  WHERE ((b.performer = a.id) AND (c.album = b.id) AND (c.type = d.id) AND (c.status = e.id) AND (c.condition = f.id));


ALTER TABLE public.viewallmedia OWNER TO amdb;

--
-- Name: viewmedia; Type: VIEW; Schema: public; Owner: amdb
--

CREATE VIEW public.viewmedia AS
 SELECT c.id,
    c.number,
    d.name AS type,
    a.name AS artist,
    b.name AS album
   FROM public.performer a,
    public.album b,
    public.media c,
    public.type d
  WHERE ((b.performer = a.id) AND (c.album = b.id) AND (c.type = d.id))
  ORDER BY a.name, b.name;


ALTER TABLE public.viewmedia OWNER TO amdb;

--
-- Name: viewperformer; Type: VIEW; Schema: public; Owner: amdb
--

CREATE VIEW public.viewperformer AS
 SELECT performer.id,
    performer.name
   FROM public.performer
  ORDER BY performer.name;


ALTER TABLE public.viewperformer OWNER TO amdb;

--
-- Data for Name: album; Type: TABLE DATA; Schema: public; Owner: amdb
--

COPY public.album (id, name, year, performer, comment) FROM stdin;
1	Test Album	2021	1	\N
\.


--
-- Name: album_id_seq; Type: SEQUENCE SET; Schema: public; Owner: amdb
--

SELECT pg_catalog.setval('public.album_id_seq', 473, true);


--
-- Data for Name: condition; Type: TABLE DATA; Schema: public; Owner: amdb
--

COPY public.condition (id, name, comment) FROM stdin;
1	Good	\N
2	Bad	\N
3	Medium	\N
\.


--
-- Name: condition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: amdb
--

SELECT pg_catalog.setval('public.condition_id_seq', 3, true);


--
-- Data for Name: media; Type: TABLE DATA; Schema: public; Owner: amdb
--

COPY public.media (id, number, type, album, comment, "timestamp", status, condition) FROM stdin;
1	2021122401	1	1	Omrecorder	2021-12-24 12:12:12.577406	1	1
\.


--
-- Name: media_id_seq; Type: SEQUENCE SET; Schema: public; Owner: amdb
--

SELECT pg_catalog.setval('public.media_id_seq', 558, true);


--
-- Data for Name: performer; Type: TABLE DATA; Schema: public; Owner: amdb
--

COPY public.performer (id, name, comment) FROM stdin;
1	Test Performer	The Netherlands
\.


--
-- Name: performer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: amdb
--

SELECT pg_catalog.setval('public.performer_id_seq', 269, true);


--
-- Data for Name: status; Type: TABLE DATA; Schema: public; Owner: amdb
--

COPY public.status (id, name, comment) FROM stdin;
1	Active	\N
2	Lost	\N
3	Broken	\N
4	Transfered	\N
\.


--
-- Name: status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: amdb
--

SELECT pg_catalog.setval('public.status_id_seq', 4, true);


--
-- Data for Name: type; Type: TABLE DATA; Schema: public; Owner: amdb
--

COPY public.type (id, name, comment) FROM stdin;
1	MD	mini disc
2	CD	compact disc
3	VD	vinyl disc
4	CT	cassette tape
5	RT	reel tape
\.


--
-- Name: type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: amdb
--

SELECT pg_catalog.setval('public.type_id_seq', 9, true);


--
-- Name: album album_pkey; Type: CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.album
    ADD CONSTRAINT album_pkey PRIMARY KEY (id);


--
-- Name: condition condition_pkey; Type: CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.condition
    ADD CONSTRAINT condition_pkey PRIMARY KEY (id);


--
-- Name: media media_number_un; Type: CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.media
    ADD CONSTRAINT media_number_un UNIQUE (number);


--
-- Name: media media_pkey; Type: CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.media
    ADD CONSTRAINT media_pkey PRIMARY KEY (id);


--
-- Name: type name_un; Type: CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.type
    ADD CONSTRAINT name_un UNIQUE (name);


--
-- Name: performer performer_pkey; Type: CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.performer
    ADD CONSTRAINT performer_pkey PRIMARY KEY (id);


--
-- Name: condition status_condition_un; Type: CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.condition
    ADD CONSTRAINT status_condition_un UNIQUE (name);


--
-- Name: status status_name_un; Type: CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.status
    ADD CONSTRAINT status_name_un UNIQUE (name);


--
-- Name: status status_pkey; Type: CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.status
    ADD CONSTRAINT status_pkey PRIMARY KEY (id);


--
-- Name: type type_pkey; Type: CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.type
    ADD CONSTRAINT type_pkey PRIMARY KEY (id);


--
-- Name: album_name_index; Type: INDEX; Schema: public; Owner: amdb
--

CREATE INDEX album_name_index ON public.album USING btree (name);


--
-- Name: media_condition_index; Type: INDEX; Schema: public; Owner: amdb
--

CREATE INDEX media_condition_index ON public.media USING btree (condition);


--
-- Name: media_number_index; Type: INDEX; Schema: public; Owner: amdb
--

CREATE INDEX media_number_index ON public.media USING btree (id);


--
-- Name: media_status_index; Type: INDEX; Schema: public; Owner: amdb
--

CREATE INDEX media_status_index ON public.media USING btree (status);


--
-- Name: media_type_index; Type: INDEX; Schema: public; Owner: amdb
--

CREATE INDEX media_type_index ON public.media USING btree (type);


--
-- Name: performer_name_index; Type: INDEX; Schema: public; Owner: amdb
--

CREATE INDEX performer_name_index ON public.performer USING btree (name);


--
-- Name: album album_performer_fk; Type: FK CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.album
    ADD CONSTRAINT album_performer_fk FOREIGN KEY (performer) REFERENCES public.performer(id);


--
-- Name: media media_album_fk; Type: FK CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.media
    ADD CONSTRAINT media_album_fk FOREIGN KEY (album) REFERENCES public.album(id);


--
-- Name: media media_condition_fk; Type: FK CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.media
    ADD CONSTRAINT media_condition_fk FOREIGN KEY (condition) REFERENCES public.condition(id);


--
-- Name: media media_status_fk; Type: FK CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.media
    ADD CONSTRAINT media_status_fk FOREIGN KEY (status) REFERENCES public.status(id);


--
-- Name: media media_type_fk; Type: FK CONSTRAINT; Schema: public; Owner: amdb
--

ALTER TABLE ONLY public.media
    ADD CONSTRAINT media_type_fk FOREIGN KEY (type) REFERENCES public.type(id);


--
-- PostgreSQL database dump complete
--

