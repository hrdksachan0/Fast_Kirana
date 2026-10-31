-- Enable PostgreSQL extensions for full-text search & trigram similarity
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Trigram index on product name for typo-tolerant fuzzy matching (e.g. "meggi", "layz")
CREATE INDEX IF NOT EXISTS idx_products_name_trgm ON products USING gin (name gin_trgm_ops);

-- Add search_vector column to products if not exists
ALTER TABLE products ADD COLUMN IF NOT EXISTS search_vector tsvector;

-- Function to keep search_vector automatically up to date
CREATE OR REPLACE FUNCTION products_search_vector_update() RETURNS trigger AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('english', coalesce(NEW.name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(array_to_string(NEW.tags, ' '), '')), 'B') ||
    setweight(to_tsvector('english', coalesce(NEW.description, '')), 'C');
  RETURN NEW;
END
$$ LANGUAGE plpgsql;

-- Attach trigger on products table
DROP TRIGGER IF EXISTS trg_products_search_vector ON products;
CREATE TRIGGER trg_products_search_vector
BEFORE INSERT OR UPDATE OF name, tags, description ON products
FOR EACH ROW EXECUTE FUNCTION products_search_vector_update();

-- Populate existing rows
UPDATE products SET search_vector = 
  setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
  setweight(to_tsvector('english', coalesce(array_to_string(tags, ' '), '')), 'B') ||
  setweight(to_tsvector('english', coalesce(description, '')), 'C')
WHERE search_vector IS NULL;

-- GIN index on search_vector for sub-millisecond full-text queries
CREATE INDEX IF NOT EXISTS idx_products_search_vector ON products USING gin(search_vector);
