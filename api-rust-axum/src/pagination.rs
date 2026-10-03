use axum::{
    extract::{FromRequestParts, Query},
    http::request::Parts,
};
use serde::Deserialize;

use crate::error::ApiError;

const DEFAULT_PAGE_SIZE: u32 = 20;
const MAX_PAGE_SIZE: u32 = 100;

#[derive(Debug, Clone, Copy)]
pub struct Pagination {
    pub page: u32,
    pub page_size: u32,
}

impl Pagination {
    pub fn limit(&self) -> i64 {
        i64::from(self.page_size)
    }

    pub fn offset(&self) -> i64 {
        i64::from(self.page - 1) * i64::from(self.page_size)
    }
}

// Raw strings so malformed values get our JSON error instead of axum's
// plain-text rejection.
#[derive(Deserialize)]
struct RawPagination {
    page: Option<String>,
    page_size: Option<String>,
}

fn parse_positive(raw: Option<&str>, fallback: u32) -> Option<u32> {
    match raw {
        None | Some("") => Some(fallback),
        Some(s) => s.parse::<u32>().ok().filter(|v| *v >= 1),
    }
}

impl<S: Send + Sync> FromRequestParts<S> for Pagination {
    type Rejection = ApiError;

    async fn from_request_parts(parts: &mut Parts, _: &S) -> Result<Self, Self::Rejection> {
        let invalid = || {
            ApiError::BadRequest(
                "'page' must be >= 1 and 'page_size' must be between 1 and 100".to_owned(),
            )
        };
        let Query(raw) = Query::<RawPagination>::try_from_uri(&parts.uri).map_err(|_| invalid())?;

        let page = parse_positive(raw.page.as_deref(), 1).ok_or_else(invalid)?;
        let page_size = parse_positive(raw.page_size.as_deref(), DEFAULT_PAGE_SIZE)
            .filter(|v| *v <= MAX_PAGE_SIZE)
            .ok_or_else(invalid)?;
        Ok(Pagination { page, page_size })
    }
}
