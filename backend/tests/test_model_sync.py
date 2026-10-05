"""db/model.py is the source of truth: generated files and the baseline must match it."""

import subprocess
import sys

from qms_api.config import REPO_ROOT


def test_generated_schema_matches_model_and_baseline():
    db = REPO_ROOT / "db"
    before = (db / "generated" / "schema.sql").read_text()
    subprocess.run([sys.executable, "gen.py"], cwd=db, check=True, capture_output=True)
    after = (db / "generated" / "schema.sql").read_text()
    assert before == after, "db/generated is stale: run `python db/gen.py` and commit"
    assert (db / "migrations" / "0001_baseline.sql").read_text() == after, (
        "0001_baseline.sql differs from the model. Before the first production deploy, copy "
        "db/generated/schema.sql over it; afterwards, write a new numbered migration instead.")
