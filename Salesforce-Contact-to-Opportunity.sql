SELECT
  email,
  contacts.id as contact_id,
  contacts.title as title,
  contacts.contact_status_c as current_contact_status,
  contacts.mql_date_c as mql_date,
  contacts.mql_category_c as mql_category,
  contacts.account_id as account_id,
  accounts.name as account_name,
  accounts.number_of_employees,
  accounts.type,
  mql_date_c<=most_recent_opp_created_date as Marketing_Sourced,
  opps.name as most_recent_opportunity_name,
  cast(opps.amount as FLOAT64) as most_recent_opportunity_amount,
  opps.created_date as most_recent_opportunity_created_date,
  opps.stage_name as most_recent_opportunity_current_stage,
  opps.id as most_recent_opportunity_id
FROM
  salesforce.contacts_view contacts
LEFT JOIN
  salesforce.opportunity_contact_role_view contact_role
ON
  contacts.id=contact_role.contact_id
LEFT JOIN
  salesforce.accounts_view accounts
ON
  contacts.account_id=accounts.id
LEFT JOIN (
  SELECT
    account_id,
    MAX(created_date) AS most_recent_opp_created_date
  FROM
    salesforce.opportunities_view
  WHERE is_deleted=FALSE
  GROUP BY
    account_id) opp_ordering
ON
  opp_ordering.account_id=accounts.id
LEFT JOIN (
  SELECT
    name,
    amount,
    created_date,
    stage_name,
    type,
    account_id,
    id
  FROM
    salesforce.opportunities_view
  where is_deleted=FALSE) opps
ON
  opps.account_id=contacts.account_id
  AND opps.created_date=most_recent_opp_created_date
  AND opps.id = contact_role.opportunity_id
WHERE
  email IS NOT NULL