SELECT
  leads.email,
  SUM(CASE
      WHEN activities.activity_type_id=6 THEN 1
    ELSE
    0
  END
    ) AS Emails_Sent,
  SUM(CASE
      WHEN activities.activity_type_id=7 THEN 1
    ELSE
    0
  END
    ) AS Emails_Delivered,
  SUM(CASE
      WHEN activities.activity_type_id=10 THEN 1
    ELSE
    0
  END
    ) AS Emails_Opened,
  SUM(CASE
      WHEN activities.activity_type_id=11 THEN 1
    ELSE
    0
  END
    ) AS Links_Clicked_in_Emails,
  SUM(CASE
      WHEN activities.activity_type_id=2 THEN 1
    ELSE
    0
  END
    ) AS Forms_Filled
FROM
  marketo.leads_view AS leads
LEFT JOIN
  marketo.lead_activities_view AS activities
ON
  leads.id=activities.lead_id
where email is not null
GROUP BY
  email
order by Forms_Filled desc