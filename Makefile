# NYC TLC Yellow Taxi Rebalancing — top-level build orchestration
#
#   make data       — download parquet + clean + features + cost matrix + validate
#   make experiment — run Baltamatica (北太天元) pipeline, then rasterise figures
#   make report     — compile report.pdf
#   make slides     — compile slides.pdf
#   make video-prep — slides.pdf → rendered PNGs (for PowerPoint import)
#   make tests      — run 3 LP unit tests in Baltamatica
#   make all        — data + experiment + report + slides
#   make clean      — remove processed/, results/, build artifacts
#   make distclean  — also remove raw/ and venv/

VENV     := .venv
PY       := $(VENV)/bin/python
PIP      := $(VENV)/bin/pip
BALTAM   := /Applications/Baltamatica.app/Contents/MacOS/baltamaticaC.sh
PROJ     := $(CURDIR)
YEAR     ?= 2024
MONTHS   ?= 1 2 3
TOPK     ?= 50

.PHONY: all venv data preprocess validate experiment figures \
        report slides video-prep tests clean distclean

all: data experiment report slides

venv: $(VENV)/bin/activate

$(VENV)/bin/activate: requirements.txt
	@echo "==> creating venv + installing deps"
	@test -d $(VENV) || python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt
	@touch $(VENV)/bin/activate

# raw data + preprocessing + validation
data: venv
	@echo "==> downloading TLC parquet ($(YEAR), months $(MONTHS))"
	$(PY) code/python/01_download_tlc.py --year $(YEAR) --months $(MONTHS)
	@echo "==> cleaning trips"
	$(PY) code/python/02_preprocess_trips.py --year $(YEAR) --months $(MONTHS)
	@echo "==> building features"
	$(PY) code/python/03_build_features.py --topk $(TOPK)
	@echo "==> building cost matrix"
	$(PY) code/python/04_build_cost_matrix.py
	@echo "==> validating outputs"
	$(PY) code/python/06_validate.py

preprocess: data    # alias

validate: venv
	$(PY) code/python/06_validate.py

# main 北太天元 pipeline + figure rasterisation
experiment:
	@echo "==> running Baltamatica (北太天元) pipeline"
	@printf "cd '$(PROJ)/code/beita';\nrun_all;\nexit\n" | $(BALTAM) 2>&1 | grep -vE "^[[:space:]]*$$|---|主创人|北太|感谢|缅怀|请使用|许可证|社区版|版本信息|帮助文档|Baltamatica" || true
	@echo
	@echo "==> rasterising figures"
	$(PY) code/python/07_render_figures.py

figures: experiment    # alias for "redo figures"; really runs full experiment

# unit tests (3 LP cases)
tests:
	@echo "==> running 北太天元 LP tests"
	@printf "cd '$(PROJ)/code/beita/tests';\naddpath('$(PROJ)/code/beita');\nrun_all_tests;\nexit\n" | $(BALTAM) 2>&1 | tail -25

# LaTeX
report:
	@echo "==> compiling report.pdf"
	cd report && latexmk -xelatex -interaction=nonstopmode report.tex

slides:
	@echo "==> compiling slides.pdf"
	cd slides && latexmk -xelatex -interaction=nonstopmode main.tex

video-prep: slides
	@echo "==> rasterising slides for PowerPoint import"
	mkdir -p slides/rendered
	pdftoppm -png -r 220 slides/main.pdf slides/rendered/slide
	@echo "→ slides/rendered/*.png ready"

clean:
	@echo "==> cleaning processed + results + LaTeX builds"
	rm -rf data/processed/*.csv data/processed/*.parquet
	rm -rf results/tables/*.csv
	rm -rf results/figures/*.png
	cd report && latexmk -C 2>/dev/null || true
	cd slides && latexmk -C 2>/dev/null || true

distclean: clean
	@echo "==> wiping raw data + venv"
	rm -rf data/raw/*.parquet data/raw/*.csv
	rm -rf $(VENV)
