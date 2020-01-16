#!/usr/bin/env python3

import json, sys, requests
from os.path import join, expandvars, expanduser
from os import environ
from enum import Enum
from akamai.edgegrid import EdgeGridAuth, EdgeRc

class SymbolicVersion(Enum):
    latest = "latest"
    staging = "staging"
    production = "production"

class PAPIError(RuntimeError):
    pass

def is_version_symbolic(v):
    return v in SymbolicVersion.__members__

class TerraformQuery(object):
    def __init__(self, kv):
        self.property = kv["property"]
        self.version = kv.get("version", SymbolicVersion.latest.name)

        self.host = None
        self.access_token = None
        self.client_token = None
        self.client_secret = None

        if "section" in kv:
            edgercPath = kv.get("edgerc", join(environ.get("HOME"), ".edgerc"))
            edgerc = EdgeRc(expandvars(expanduser(edgercPath)))
            section = kv.get("section", "papi")
            self.host = edgerc.get(section, "host")
            self.access_token = edgerc.get(section, "access_token")
            self.client_token = edgerc.get(section, "client_token")
            self.client_secret = edgerc.get(section, "client_secret")

        self.baseUrl = "https://{0}".format(kv.get("host", self.host))
        self.access_token = kv.get("access_token", self.access_token)
        self.client_token = kv.get("client_token", self.client_token)
        self.client_secret = kv.get("client_secret", self.client_secret)

class PropertyDescriptor(object):
    def __init__(self, contractId, groupId, propertyId, **kwargs):
        self.contractId = contractId
        self.groupId = groupId
        self.propertyId = propertyId

def get_property_descriptor(session, baseUrl, propertyName):
    url = "{baseUrl}/papi/v1/search/find-by-value".format(baseUrl=baseUrl)
    result = session.post(url, data=json.dumps({
        "propertyName": propertyName
    }), headers={"Content-Type": "application/json"})
    if result.status_code != 200:
        raise PAPIError("{0} returned status {1}".format(url, result.status_code))
    result = result.json()
    versions = result.get("versions", {}).get("items", [])
    if len(versions) > 0:
        return PropertyDescriptor(**versions[0])
    raise PAPIError("get_property did not find any versions for {0}".format(propertyName))

def get_property_rule_tree(session, baseUrl, pd, propertyVersion):
    url = "{baseUrl}/papi/v1/properties/{propertyId}/versions/{propertyVersion}/rules".format(
        baseUrl=baseUrl,
        propertyId=pd.propertyId,
        propertyVersion=propertyVersion
    )
    result = session.get(url, params={
        "contractId": pd.contractId,
        "groupId": pd.groupId,
        "validateRules": False
    })
    if result.status_code != 200:
        raise PAPIError("{0} returned status {1}".format(url, result.status_code))
    return result.json()

def get_symbolic_property_version(session, baseUrl, pd, version):
    url = "{baseUrl}/papi/v1/properties/{propertyId}".format(
        baseUrl=baseUrl,
        propertyId=pd.propertyId
    )
    result = session.get(url, params={
        "contractId": pd.contractId,
        "groupId": pd.groupId
    })
    if result.status_code != 200:
        raise PAPIError("{0} returned status {1}".format(url, result.status_code))
    result = result.json().get("properties", {}).get("items", []).pop(0)
    return result.get("{0}Version".format(version.name))

try:
    q = json.loads(sys.stdin.read(), object_hook=TerraformQuery)
except KeyError as e:
    print("Expecting option: {0}".format(e), file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print("{0}: {1}".format(type(e).__name__, " ".join(e.args)), file=sys.stderr)
    sys.exit(1)

try:
    with requests.Session() as session:
        session.auth = EdgeGridAuth(
            access_token=q.access_token,
            client_token=q.client_token,
            client_secret=q.client_secret
        )

        pd = get_property_descriptor(session, q.baseUrl, q.property)
        version = q.version
        if is_version_symbolic(version):
            version = str(get_symbolic_property_version(session, q.baseUrl, pd, SymbolicVersion(version)))

        rules = get_property_rule_tree(session, q.baseUrl, pd, version)
        rules = {"rules": rules.get("rules"), "rule_format": rules.get("rule_format")}
        print(json.dumps({"tree": json.dumps(rules)}))
except Exception as e:
    print("{0}: {1}".format(type(e).__name__, " ".join(e.args)), file=sys.stderr)
    sys.exit(2)
