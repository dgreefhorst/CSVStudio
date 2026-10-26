import Foundation

struct Vocabulary: Identifiable {
    let prefix: String
    let namespace: String
    let title: String
    let properties: [String]
    let classes: [String]

    var id: String { prefix }
}

enum Vocabularies {
    static let all: [Vocabulary] = [
        Vocabulary(
            prefix: "rdf", namespace: "http://www.w3.org/1999/02/22-rdf-syntax-ns#", title: "RDF",
            properties: ["type", "value", "first", "rest"],
            classes: ["Property", "Statement", "List", "Bag", "Seq", "Alt"]),
        Vocabulary(
            prefix: "rdfs", namespace: "http://www.w3.org/2000/01/rdf-schema#", title: "RDF Schema",
            properties: ["label", "comment", "seeAlso", "isDefinedBy", "subClassOf", "subPropertyOf", "domain", "range", "member"],
            classes: ["Class", "Resource", "Literal", "Datatype", "Container"]),
        Vocabulary(
            prefix: "owl", namespace: "http://www.w3.org/2002/07/owl#", title: "OWL",
            properties: ["sameAs", "differentFrom", "equivalentClass", "equivalentProperty", "inverseOf", "disjointWith", "versionInfo", "versionIRI", "priorVersion", "imports", "deprecated"],
            classes: ["Class", "ObjectProperty", "DatatypeProperty", "AnnotationProperty", "NamedIndividual", "Ontology", "Thing"]),
        Vocabulary(
            prefix: "xsd", namespace: "http://www.w3.org/2001/XMLSchema#", title: "XML Schema datatypes",
            properties: [], classes: []),
        Vocabulary(
            prefix: "skos", namespace: "http://www.w3.org/2004/02/skos/core#", title: "SKOS",
            properties: ["prefLabel", "altLabel", "hiddenLabel", "definition", "notation", "note", "scopeNote", "example", "historyNote", "editorialNote", "changeNote", "broader", "narrower", "related", "broaderTransitive", "narrowerTransitive", "inScheme", "hasTopConcept", "topConceptOf", "member", "exactMatch", "closeMatch", "broadMatch", "narrowMatch", "relatedMatch"],
            classes: ["Concept", "ConceptScheme", "Collection", "OrderedCollection"]),
        Vocabulary(
            prefix: "dcterms", namespace: "http://purl.org/dc/terms/", title: "Dublin Core Terms",
            properties: ["title", "alternative", "description", "abstract", "identifier", "creator", "contributor", "publisher", "subject", "date", "created", "modified", "issued", "valid", "available", "language", "type", "format", "extent", "medium", "source", "relation", "rights", "license", "accessRights", "isPartOf", "hasPart", "isVersionOf", "hasVersion", "replaces", "isReplacedBy", "references", "isReferencedBy", "requires", "conformsTo", "spatial", "temporal", "coverage", "audience", "provenance", "tableOfContents", "bibliographicCitation"],
            classes: ["Agent", "AgentClass", "BibliographicResource", "Location", "LicenseDocument", "MediaType", "PeriodOfTime", "Standard", "RightsStatement"]),
        Vocabulary(
            prefix: "dc", namespace: "http://purl.org/dc/elements/1.1/", title: "Dublin Core Elements",
            properties: ["title", "creator", "subject", "description", "publisher", "contributor", "date", "type", "format", "identifier", "source", "language", "relation", "coverage", "rights"],
            classes: []),
        Vocabulary(
            prefix: "foaf", namespace: "http://xmlns.com/foaf/0.1/", title: "FOAF",
            properties: ["name", "givenName", "familyName", "firstName", "lastName", "nick", "title", "mbox", "mbox_sha1sum", "homepage", "weblog", "workplaceHomepage", "phone", "depiction", "img", "age", "gender", "birthday", "knows", "member", "account", "accountName", "primaryTopic", "topic", "page", "made", "maker", "interest"],
            classes: ["Person", "Agent", "Organization", "Group", "Document", "Image", "OnlineAccount", "Project"]),
        Vocabulary(
            prefix: "schema", namespace: "https://schema.org/", title: "Schema.org",
            properties: ["name", "alternateName", "description", "disambiguatingDescription", "identifier", "url", "sameAs", "image", "email", "telephone", "faxNumber", "address", "streetAddress", "postalCode", "addressLocality", "addressRegion", "addressCountry", "givenName", "familyName", "additionalName", "honorificPrefix", "jobTitle", "birthDate", "deathDate", "gender", "nationality", "worksFor", "memberOf", "affiliation", "parentOrganization", "subOrganization", "legalName", "foundingDate", "taxID", "vatID", "leiCode", "location", "geo", "latitude", "longitude", "contactPoint", "startDate", "endDate", "datePublished", "dateCreated", "dateModified", "author", "creator", "publisher", "inLanguage", "keywords", "about", "license", "price", "priceCurrency", "sku", "brand", "manufacturer", "category", "isPartOf", "hasPart", "version", "productID", "areaServed", "openingHours"],
            classes: ["Thing", "Person", "Organization", "Corporation", "GovernmentOrganization", "LocalBusiness", "Place", "PostalAddress", "GeoCoordinates", "Country", "City", "Event", "Product", "Offer", "CreativeWork", "Dataset", "Article", "Book", "WebSite", "WebPage", "ContactPoint"]),
        Vocabulary(
            prefix: "vcard", namespace: "http://www.w3.org/2006/vcard/ns#", title: "vCard",
            properties: ["fn", "given-name", "family-name", "additional-name", "honorific-prefix", "nickname", "hasEmail", "hasTelephone", "hasURL", "hasAddress", "hasLogo", "hasPhoto", "organization-name", "organization-unit", "title", "role", "street-address", "locality", "region", "postal-code", "country-name", "note", "bday", "hasGeo", "latitude", "longitude"],
            classes: ["Individual", "Organization", "Kind", "Address", "Group", "Location"]),
        Vocabulary(
            prefix: "prov", namespace: "http://www.w3.org/ns/prov#", title: "PROV-O",
            properties: ["wasDerivedFrom", "wasGeneratedBy", "wasAttributedTo", "wasAssociatedWith", "wasInformedBy", "used", "generatedAtTime", "invalidatedAtTime", "startedAtTime", "endedAtTime", "actedOnBehalfOf", "hadPrimarySource", "specializationOf", "alternateOf", "atLocation", "value"],
            classes: ["Entity", "Activity", "Agent", "Person", "Organization", "SoftwareAgent", "Collection"]),
        Vocabulary(
            prefix: "dcat", namespace: "http://www.w3.org/ns/dcat#", title: "DCAT",
            properties: ["theme", "keyword", "distribution", "dataset", "service", "landingPage", "accessURL", "downloadURL", "mediaType", "byteSize", "contactPoint", "endpointURL", "endpointDescription", "version", "temporalResolution", "spatialResolution", "compressFormat", "packageFormat", "startDate", "endDate", "record", "catalog", "inSeries"],
            classes: ["Catalog", "Dataset", "Distribution", "DataService", "CatalogRecord", "Resource", "DatasetSeries", "Relationship", "Role"]),
        Vocabulary(
            prefix: "org", namespace: "http://www.w3.org/ns/org#", title: "W3C Organization",
            properties: ["memberOf", "hasMember", "headOf", "subOrganizationOf", "hasSubOrganization", "hasUnit", "unitOf", "role", "holds", "heldBy", "reportsTo", "hasSite", "hasPost", "postIn", "basedAt", "linkedTo", "purpose", "classification", "organization", "member"],
            classes: ["Organization", "FormalOrganization", "OrganizationalUnit", "OrganizationalCollaboration", "Membership", "Role", "Post", "Site"]),
        Vocabulary(
            prefix: "geo", namespace: "http://www.w3.org/2003/01/geo/wgs84_pos#", title: "WGS84 Geo",
            properties: ["lat", "long", "alt", "location"],
            classes: ["SpatialThing", "Point"]),
        Vocabulary(
            prefix: "locn", namespace: "http://www.w3.org/ns/locn#", title: "ISA Location",
            properties: ["address", "fullAddress", "geometry", "postCode", "postName", "thoroughfare", "locatorDesignator", "locatorName", "adminUnitL1", "adminUnitL2", "addressArea", "poBox", "addressId"],
            classes: ["Address", "Geometry"]),
        Vocabulary(
            prefix: "adms", namespace: "http://www.w3.org/ns/adms#", title: "ADMS",
            properties: ["identifier", "status", "versionNotes", "sample", "representationTechnique", "supportedSchema"],
            classes: ["Identifier", "Asset", "AssetDistribution", "AssetRepository"]),
        Vocabulary(
            prefix: "sh", namespace: "http://www.w3.org/ns/shacl#", title: "SHACL",
            properties: ["name", "description", "path", "targetClass", "class", "datatype", "minCount", "maxCount", "nodeKind", "property", "pattern", "in", "order", "group", "message", "severity"],
            classes: ["NodeShape", "PropertyShape"])
    ]

    /// Alle bekende voorvoegsels (inclusief enkele gangbare aliassen).
    static let namespaces: [String: String] = {
        var d = [String: String]()
        for v in all { d[v.prefix] = v.namespace }
        d["dct"] = "http://purl.org/dc/terms/"
        return d
    }()
}
