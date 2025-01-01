-- CTE to condense Salesforce Leads and Contacts into 'People'
WITH people
as ( -- Selecting relevant fields from Salesforce Leads
   SELECT leads.email as person_email,
          leads.id as person_id,
          DATE(leads.createddate) as person_created_date,
          DATE(leads.mql_date__c) as person_mql_date, --If you don't have this field, remove this line
          leads.mql_category__c as person_mql_category, --If you don't have this field, remove this line
          leads.status as person_status,
          leads.original_source__c as person_original_source, --If you don't have this field, replace with your chosen 'Lead Source' field
          leads.title as person_title
   FROM SFDC_LEAD as leads
   WHERE
       -- Restricting to valid unconverted Leads and those with recent engagement
       isconverted = FALSE
       and leads.email is not null
       and isdeleted = FALSE
       and (
               DATE(leads.createddate) >= DATE('2023-01-01')
               OR DATE(leads.mql_date__c) >= DATE('2023-01-01')
           )
   -- Using UNION to 'stack' Unconverted Leads and Contacts into 'people'
   UNION
   -- Selecting relevant fields from Salesforce Contacts
   SELECT contacts.email as person_email,
          contacts.id as person_id,
          DATE(contacts.createddate) as person_created_date,
          DATE(contacts.mql_date__c) as person_mql_date, --If you don't have this field, remove this line
          contacts.mql_category__c as person_mql_category, --If you don't have this field, remove this line
          contacts.contact_status__c as person_status,
          contacts.original_source__c as person_original_source, --If you don't have this field, replace with your chosen 'Lead Source' field
          contacts.title as person_title
   FROM SFDC_CONTACT as contacts
   WHERE
       -- Restricting to valid Contacts with recent engagement
       contacts.email is not null
       and contacts.isdeleted = FALSE
       and (
               DATE(contacts.createddate) >= DATE(2023 - 01 - 01)
               OR DATE(contacts.mql_date__c) >= DATE(2023 - 01 - 01)
           )
   ),
     -- CTE to gather Salesforce Opportunity data
     opportunity_data
as (
   -- Selecting relevant fields from Opportunity Contact Roles
   -- JOINing Opportunity Contact Role data with Opportunity Data
   SELECT opp_roles.contactid as opportunity_role_contact_id,
          opp_roles.opportunityid as opportunity_id,
          opps.name as opportunity_name,
          DATE(opps.createddate) as opportunity_created_date,
          DATE(opps.closedate) as opportunity_close_date,
          opps.leadsource as opportunity_lead_source,
          opps.stagename as opportunity_stage,
          opps.amount as opportunity_amount
   FROM SFDC_OPPORTUNITYCONTACTROLE as opp_roles
       JOIN SFDC_OPPORTUNITY opps
           on opp_roles.opportunityid = opps.id
       JOIN
       ( -- Using a sub-query to only retrieve the Most Recent Opportunity
           select opps2.ACCOUNTID,
                  max(opps2.createddate) as opp_created
           from SFDC_OPPORTUNITY opps2
           group by accountid
       ) most_recent
           ON most_recent.ACCOUNTID = opps.accountid
              and most_recent.opp_created = opps.createddate
   WHERE
       -- Restricting Opportunity Data to only New Business and Primary Contacts
       opps.type = 'New Business'
       and NOT (CONTAINS(opps.name, 'Self-Managed')) --Remove this line or change this based on your business logic
       and opp_roles.isprimary = TRUE
       and opp_roles.isdeleted = FALSE
       and opps.isdeleted = FALSE
   )
-- Final SELECT, unifying 'person' data with Opportunity data
SELECT DISTINCT
    person_email,
    person_id,
    person_created_date,
    person_mql_date,
    person_mql_category,
    person_status,
    person_original_source,
    person_title,
    opportunity_id,
    opportunity_name,
    opportunity_created_date,
    opportunity_close_date,
    opportunity_lead_source,
    opportunity_stage,
    opportunity_amount
from people
    left outer join opportunity_data
        on people.person_id = opportunity_data.opportunity_role_contact_id