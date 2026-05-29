# Reference sample for the standalone cra-bdd suite (Increment 11).
# Target path: cra-bdd/src/test/resources/features/srp/srp_workflow.feature
# White-box sad paths (state-machine races, payload-completeness edge cases)
# are covered by SrpReportWorkflowIT in the companion module.

@RF-6-3 @CRA-Art14.1 @srp
Feature: SRP report approval workflow
  A Security Analyst assembles a Single Reporting Platform report for an
  actively-exploited (KEV/EUVD) finding and must approve it before it can be sent.

  Background:
    Given the platform is healthy with Dependency-Track connected
    And the CISA KEV catalogue has been mirrored
    And a release "PLC-X100 / 5.1.0" exists with an uploaded SBOM
    And a finding for "CVE-2021-44228" on that release is flagged as KEV

  # ---------------- Happy path ----------------

  Scenario: Analyst drafts, submits and approves an SRP report for a KEV finding
    Given I am authenticated as a "Security Analyst"
    When I create an SRP report draft for finding "CVE-2021-44228"
    Then the response status is 201
    And the report status is "draft"
    And the report payload contains the component PURL, CVSS score and affected release

    When I submit the report for approval
    Then the response status is 200
    And the report status is "pending_approval"

    When I approve the report
    Then the response status is 200
    And the report status is "approved"
    And an audit record "SRP_REPORT_APPROVED" exists with my username

  # ---------------- Sad paths (HTTP-observable) ----------------

  Scenario: Cannot approve a report that was never submitted
    Given I am authenticated as a "Security Analyst"
    And an SRP report draft exists for finding "CVE-2021-44228" in status "draft"
    When I approve the report
    Then the response status is 409
    And the error code is "INVALID_STATE_TRANSITION"

  Scenario: A non-analyst role cannot approve a report
    Given I am authenticated as a "Developer"
    And an SRP report exists for finding "CVE-2021-44228" in status "pending_approval"
    When I approve the report
    Then the response status is 403

  Scenario: Cannot edit a report after approval
    Given I am authenticated as a "Security Analyst"
    And an SRP report exists for finding "CVE-2021-44228" in status "approved"
    When I update the report payload
    Then the response status is 409
    And the error code is "REPORT_LOCKED"

  Scenario: Unauthenticated requests are rejected
    Given I am not authenticated
    When I create an SRP report draft for finding "CVE-2021-44228"
    Then the response status is 401

  Scenario Outline: Drafting against an ineligible finding is rejected
    Given I am authenticated as a "Security Analyst"
    And a finding for "<cve>" exists on the release and is "<flag>"
    When I create an SRP report draft for finding "<cve>"
    Then the response status is <status>

    # SRP scope (RF-6) is KEV/EUVD only; non-exploited findings are not reportable.
    Examples:
      | cve            | flag           | status |
      | CVE-2021-44228 | KEV-flagged    | 201    |
      | CVE-2020-0001  | not exploited  | 422    |
