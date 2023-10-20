# README

Gumroad [Product engineering challenge](https://gumroad.notion.site/Product-engineering-challenge-f7aa85150edd41eeb3537aae4632619f) done by [Eugene Mirotin](https://mirotin.online).

## How to run

1. Clone the repo
1. Have ruby, bundler, node.js, and yarn installed, run `bundle install` and `yarn install`
1. Set `OPENAI_API_KEY` and (optional) `OPENAI_ORG_ID` in the `.env` file
1. Run `bin/dev`

## How to generate book embeddings

1. Fill the `.env` file
1. Run `bin/pdf_to_pages_embeddings --pdf book.pdf` from the root of the project
