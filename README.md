# BrainVision BVRF Reader – MATLAB/EEGLAB Plugin

This plugin lets you import BrainVision Recording Format (BVRF) datasets into MATLAB and EEGLAB. It supports the full BVRF 1.0.0 file set:

- Header: `*.bvrh` 
- Data: `*.bvrd` 
- Marker: `*.bvrm` 
- Impedance: `*.bvri` 

The plugin reads the header, data, markers and impedances, and creates one EEGLAB `EEG` structure per participant.

## Files and functions provided

The plugin consists of three main functions:

1. **`eegplugin_bvrfimport`**  
   EEGLAB plugin entry point. Adds a menu item to EEGLAB:
   > *File → Import data → From BrainVision (BVRF)...*

2. **`pop_loadbvrf`**  
   EEGLAB “pop_” function with GUI and history support.

3. **`eeg_loadbvrf`**  
   Low-level loader: reads BVRF files and returns EEGLAB `EEG` structs.


## Installation

### EEGLAB
1. Copy the plugin folder into your EEGLAB `plugins` directory:
   ```
   eeglab/plugins/bvrfimport/
   ```
2. Start or restart EEGLAB.
3. You should now see a menu entry:  
   **File → Import data → From BrainVision (BVRF)...**

### MATLAB
  Do not need installation. Use the function eeg_loadbvrf directly.


## 1. Using the EEGLAB GUI

### Menu location

> **File → Import data → From BrainVision (BVRF)...**

This opens the BVRF Reader GUI included with the plugin.

### BVRF Reader GUI

The GUI shows:

- Dataset information (BVRF version, data type, sample count, sampling rate)
- Participant list with channel counts
- Options for:
  - Single or multi-participant import
  - Sample interval import (samples or seconds)
  - Channel index selection
  - Marker and impedance import
  - Apply sensor calibration if coefficients are present.

![image](docs/bvrf_ui_1.png)


## 2. Using `pop_loadbvrf` (with GUI or scripting)

### Syntax

```matlab
[ALLEEG, com] = pop_loadbvrf(hdrPath, hdrFileName, 'key', value, ...);
[ALLEEG, com] = pop_loadbvrf;  % launches GUI
```

### Optional parameters

| Parameter | Description |
|----------|-------------|
| `sampleInterval` | `[first last]` sample indices (1‑based). Empty = full dataset. |
| `channelIndx` | Vector of channel indices. Empty = all. |
| `flagImportMarkers` | `true`/`false` (default true). |
| `flagImportImpedances` | `true`/`false` (default false). |
| `participantId` | Import only this participant. |
| `usePoly` | `true`/`false` (default: true). Use channels coefficients to calibrate sensor measurements.  |

### Example

```matlab
[ALLEEG, com] = pop_loadbvrf('/data/', 'rec.bvrh', ...
    'sampleInterval', [0 100000], ...
    'channelIndx', 1:32, ...
    'flagImportMarkers', true);
```

## 3. Using `eeg_loadbvrf` directly (low-level loader)

### Syntax

```matlab
[hdr, ALLEEG] = eeg_loadbvrf(hdrPath, hdrFileName, 'key', value, ...);
```

### Example

```matlab
[hdr, ALLEEG] = eeg_loadbvrf('/data/', 'rec.bvrh', ...
    'sampleInterval', [0 600000], ...
    'flagImportMarkers', true, ...
    'verbose', true);
```

## How BVRF fields map to EEGLAB
This section describes how `eeg_loadbvrf` converts a BVRF dataset into the `EEG` structures, one per participant.

### 1. Core Data and Timing

| EEGLAB Field | Source / Meaning |
| ------------ | ---------------- |
| `EEG.data`   | Signal data read from `*.bvrd`. Channels appear in the same order as in the **Channels** section of the header. Data are converted to physical units using `ResolutionPerBit` and, optionally, polynomial coefficients. |
| `EEG.nbchan` | Number of imported channels (rows of `EEG.data`). |
| `EEG.pnts`   | Number of samples (columns of `EEG.data`). |
| `EEG.srate`  | Sampling rate from the header (`SamplingFrequencyInHertz`). |
| `EEG.trials` | Always `1` (continuous data). |
| `EEG.xmin`   | `0`. |
| `EEG.xmax`   | `EEG.pnts / EEG.srate`. |
| `EEG.comments` | Contains `Original file: <full path to .bvrh>` to document the source. |

### 2. Participants and Dataset Naming

Participants are inferred from `Channels(k).ParticipantId`:

- If present, channels are grouped per participant, generating one EEGLAB dataset per ID.  
- If absent, the recording is treated as single-participant with ID `participant-1`.

You can optionally import a specific participant via the `participantId` argument.

| EEGLAB Field             | Source / Meaning |
| ------------------------ | ---------------- |
| `EEG.subject`            | The participant ID (string). |
| `EEG.etc.participant_id` | Same as `EEG.subject`. |
| `EEG.condition`          | If the header contains `Task.Name`, it is used; otherwise empty. |
| `EEG.setname`            | `<TaskName>_<ParticipantId>` if available, otherwise `BVRF_<ParticipantId>`. |

### 3. Channels and Locations (`EEG.chanlocs`)

Channel definitions come from the BVRF **Channels** section.  
Coordinates come from **Electrodes** if provided.

| EEGLAB `chanlocs` Field | Source / Meaning |
| ----------------------- | ---------------- |
| `labels`                | `Channels(k).Name`, or fallback `Ch<k>`. |
| `type`                  | `Channels(k).Type` (e.g., `EEG`, `EOG`, `GSR`, `MISC`). |
| `X`, `Y`, `Z`           | 3D coordinates if the channel’s `Composition.Plus` points to an electrode with defined coordinates. Otherwise left empty. |

---

### 4. Reference Handling (`EEG.ref`)

The channel’s reference is inferred from the **Minus** part of its `Composition`.  
The plugin summarizes the reference following EEGLAB conventions:

| Condition                                   | Resulting `EEG.ref` |
| ------------------------------------------- | -------------------- |
| No channel has a Minus                      | `'unknown'`          |
| Some have Minus, others don’t               | `'unknown'`          |
| All have Minus but with different Minus     | `'unknown'`          |
| All channels share the same Minus with name | that name (e.g. `Cz`, `REF`) |
| All channels share the same Minus, name empty | `'common'`          |

Full reference definitions from the header are preserved as:

- `EEG.etc.bvrf.references`

### 5. Markers to `EEG.event`

Markers are read from the BVRF `*.bvrm` file and assigned to participants based on their `ParticipantId`.  
Markers without a participant ID or marked “all participants” are assigned to every participant.

#### 5.1 Standard EEGLAB Event Fields

| EEGLAB Field | Source / Meaning |
| ------------ | ---------------- |
| `type`       | Built from BVRF `Type`, `Code`, `Value`: (1) `Type/Code/Value`, (2) `Type/Code`, (3) `Type/Value`, or (4) `Type` alone. If `Type` is missing, a default `"Marker"` label is used. |
| `latency`    | Determined in this order: (1) `Sample` (preferred), (2) `SampleIndex`, (3) `Time` converted to samples via `1 + round(Time * srate)`. |
| `comment`    | BVRF `Comment` field or empty if missing. |

#### 5.2 BVRF-Specific Event Fields

These fields retain the original structure of BVRF markers:

| EEGLAB Event Field | Source |
| ------------------ | ------ |
| `bv_type`          | Original BVRF `Type`. |
| `bv_code`          | BVRF `Code`. |
| `bv_value`         | BVRF `Value`. |
| `bv_StartEndId`    | GUID linking start/end markers of duration events. |
| `bv_channel`       | Channel associated with the marker (empty = all channels). |

This makes it possible to reconstruct durations, filter marker classes, or re-export them.

### 6. Impedances to `EEG.etc.impedances`

If `flagImportImpedances` is `true` and a `*.bvri` file exists:

- The full impedance table is imported.
- Each column becomes a field in a struct.
- Each field contains a cell array of impedance values.

Attached to each dataset as:

- `EEG.etc.impedances`

### 7. Full Header and Metadata (`EEG.etc`)

To maintain provenance and allow reconstruction or debugging, the reader stores the full header:

| EEGLAB Field           | Meaning |
| ---------------------- | ------- |
| `EEG.etc.bvrf_header`  | Full parsed BVRF header (`*.bvrh`). |
| `EEG.etc.participant_id` | Participant ID. |
| `EEG.etc.bvrf.references` | Reference definitions from the header. |

You may remove `EEG.etc.bvrf_header` to reduce dataset size after import.

### 8. Sensor Scaling and Polynomials

Raw values (NV) in `*.bvrd` are converted into physical quantities (MQ) using:

- `ResolutionPerBit`  
- Optional rational polynomial coefficients (`Coefficients.Num`, `Coefficients.Denom`)

For each channel:

1. If a polynomial is defined and `usePoly = true`:

   ```text
   MQ = evalRationalPolyAscending(NV, Num, Denom, ResolutionPerBit)

## Known limitations

- Importing fiducials coordinates is not supported currently
- Create post processing function to re-evaluete the sensors data given a new set of coefficients.

## License
MIT

