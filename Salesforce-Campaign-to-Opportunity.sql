-- CTE to condense Salesforce Leads and Contacts into 'People'
WITH people
as ( -- Selecting relevant fields from Salesforce Leads
   SELECT leads.email as person_email,
          leads.id as person_id,
          DATE(leads.createddate) as person_created_date,
          DATE(leads.mql_date__c) as person_mql_date, --If you don't have this field, remove this line
          leads.mql_category__c as person_mql_category, --If you don't have this field, remove this line
          leads.status as person_status,
          leads.original_source__c as person_original_source,
          leads.title as person_title
   FROM SFDC_LEAD as leads
   WHERE
       -- Restricting to valid unconverted Leads and those with recent engagement
       isconverted = FALSE
       and isdeleted = FALSE
       and (
               DATE(leads.createddate) >= DATE('2023-01-01')
               OR DATE(leads.mql_date__c) >= DATE('2023-01-01')
           )
   -- Using UNION to 'stack' Unconverted Leads and Contacts into 'people'
   UNION ALL
   -- Selecting relevant fields from Salesforce Contacts
   SELECT contacts.email as person_email,
          contacts.id as person_id,
          DATE(contacts.createddate) as person_created_date,
          DATE(contacts.mql_date__c) as person_mql_date, --If you don't have this field, remove this line
          contacts.mql_category__c as person_mql_category, --If you don't have this field, remove this line
          contacts.contact_status__c as person_status,
          contacts.original_source__c as person_original_source,
          contacts.title as person_title
   FROM SFDC_CONTACT as contacts
   WHERE
       -- Restricting to valid Contacts with recent engagement
       isdeleted = FALSE
       and (
               DATE(contacts.createddate) >= DATE('2023-01-01')
               OR DATE(contacts.mql_date__c) >= DATE('2023-01-01')
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
   WHERE
       -- Restricting Opportunity Data to only New Business and Primary Contacts
       opps.type = 'New Business'
       and NOT (CONTAINS(opps.name, 'Self-Managed'))
       and opp_roles.isprimary = TRUE
       and opp_roles.isdeleted = FALSE
       and opps.isdeleted = FALSE
       and DATE(opps.createddate) >= DATE('2023-01-01')
   ),
   -- CTE to gather Campaign and Campaign Member Data
   campaign_data 
   as (
   -- Selectng relevant fields from Campaigns
   -- JOINing Campaign Member data with Campaign Data
   SELECT 
       case when contactid is not null then contactid else lead id end as person_id,
       campaigns.name as campaign_name,
       campaigns.type as campaign_type,
       campaigns.budget as campaign_budget,
       campaigns.status as campaign_status,
       DATE(campaigns.startdate) as campaign_start_date,
       DATE(members.createddate) as member_first_associated,
       DATE(members.respondeddate) as member_first_responded
   FROM SFDC_CAMPAIGNS as campaigns
       JOIN SFDC_CAMPAIGN_MEMBERS as members
          ON campaigns.id = members.campaignid
   )
-- Final SELECT, unifying 'person' data with Opportunity data
SELECT DISTINCT
    campaign_data.campaign_name,
    campaign_data.campaign_type,
    campaign_data.campaign_budget,
    campaign_data.campaign_start_data,
    campaign_data.member_first_associated,
    person_email,
    person_id,
    person_created_date,
    person_mql_date,
    person_mql_category,
    person_status,
    person_original_source,
    person_title,
    CASE 
        WHEN DATEDIFF(day,campaign_data.member_first_associated, opportunity_created_date)>=0 
            AND DATEDIFF(day,campaign_data.member_first_associated, opportunity_created_date)<=60
        THEN "Influenced New Opportunity"
        WHEN DATEDIFF(day,campaign_data.member_first_associated, opportunity_created_date)>=0
            AND DATEDIFF(day, campaign_data.member_first_associated, opportunity_close_date)>0
        THEN "Influenced Existing Opportunity"
        ELSE null
    END
    opportunity_id,
    opportunity_name,
    opportunity_created_date,
    opportunity_close_date,
    opportunity_lead_source,
    opportunity_stage,
    opportunity_amount
from campaign_data
    left outer join people
        on people.person_id = campaign_data.person_id
    left outer join opportunity_data
        on people.person_id = opportunity_data.opportunity_role_contact_id