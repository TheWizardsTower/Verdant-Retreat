import { useBackend } from '../backend';
import { Box, Button, Collapsible, Dropdown, LabeledList, Section, Slider, Stack, Table, Tooltip } from 'tgui-core/components';
import { Window } from '../layouts';

type FluidRow = { name: string; path: string; color: string };
type VolumeRow = { name: string; color: string; amount: number };
type PoolRow = { x: number; y: number; z: number; count: number; total: number; avg: number };
type EndpointRow = { x: number; y: number; z: number; rate: number; fluidsum: number };

type CellData = {
  x: number;
  y: number;
  z: number;
  turf_type: string;
  fluidsum: number;
  band: string;
  vis_band: string;
  is_source: boolean;
  production_rate: number;
  is_sink: boolean;
  absorption_rate: number;
  flow_dir: string;
  sim_exempt: boolean;
  contain_max: number;
  pressure_mask: number;
  doused: boolean;
  water_level: number;
  absorption: number;
  volumes: VolumeRow[];
};

type Data = {
  engine: {
    ready: boolean;
    mass?: number;
    mass_delta: number;
    drained?: number;
    native_active?: number;
    deltas: number;
    events: number;
    falls: number;
    queue: number;
    cells_active: number;
    cells_sleeping: number;
    wet_turfs: number;
    sources: number;
    sinks: number;
  };
  fluids: FluidRow[];
  tool: string;
  paint_mode: string;
  brush_size: number;
  brush_str: number;
  sel_fluid: string;
  overlay_on: boolean;
  overlay_range: number;
  flow_dir_choice: number;
  flow_apply_mode: string;
  flow_selected: number;
  flow_capped: boolean;
  cell: CellData | null;
  pool: { count: number; total: number; avg: number; min: number; max: number; dominant: string } | null;
  pools: PoolRow[];
  pools_capped: boolean;
  source_list: EndpointRow[];
  source_total: number;
  sink_list: EndpointRow[];
  sink_total: number;
};

const C = {
  bgControl: '#25252e',
  borderSubtle: '#2a2a35',
  textMuted: '#b0b0b8',
  accentBg: '#3d3770',
  accentLight: '#8878c8',
  water: '#5096ff',
  success: '#5fdc80',
  error: '#ff6868',
};

const SelectCellIcon = () => (
  <svg width="20" height="20" viewBox="0 0 64 64" fill="none">
    <rect x="10" y="10" width="36" height="36" rx="5" stroke="#9aa2b1" strokeWidth="4" />
    <path d="M22 10V46M34 10V46M10 22H46M10 34H46" stroke="#6B7280" strokeWidth="4" />
    <rect x="22" y="22" width="12" height="12" rx="2" fill="#6366F1" opacity="0.4" stroke="#6366F1" strokeWidth="4" />
    <path d="M39 39L55 45L48 49L44 57L39 39Z" fill="#FFFFFF" stroke="#1F2937" strokeWidth="4" />
  </svg>
);

const DropletIcon = () => (
  <svg width="20" height="20" viewBox="0 0 64 64" fill="none">
    <path
      d="M32 7C32 7 17 25 17 39C17 48 23.7 55 32 55C40.3 55 47 48 47 39C47 25 32 7 32 7Z"
      fill="#2563EB"
      opacity="0.45"
      stroke="#9aa2b1"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="4"
    />
    <path d="M32 35V49M25 42H39" stroke="#22C55E" strokeLinecap="round" strokeLinejoin="round" strokeWidth="4" />
  </svg>
);

const FlowIcon = () => (
  <svg width="20" height="20" viewBox="0 0 64 64" fill="none">
    <path
      d="M8 22 Q20 14 32 22 Q44 30 56 22"
      stroke="#5096ff"
      strokeLinecap="round"
      strokeWidth="5"
    />
    <path
      d="M8 34 Q20 26 32 34 Q44 42 56 34"
      stroke="#50c8ff"
      strokeLinecap="round"
      strokeWidth="5"
    />
    <path d="M40 44L58 50L50 54L46 62L40 44Z" fill="#FFFFFF" stroke="#1F2937" strokeWidth="3" />
  </svg>
);

const EraserIcon = () => (
  <svg width="14" height="14" viewBox="0 0 256 256" fill="none">
    <g strokeLinecap="round" strokeLinejoin="round">
      <path
        d="M59 150 L132 77 Q141 68 151 78 L197 124 Q207 134 198 143 L126 216 Q116 226 106 216 L59 169 Q49 159 59 150 Z"
        fill="#7D8798"
        stroke="#11161f"
        strokeWidth="16"
      />
      <path
        d="M132 77 Q141 68 151 78 L197 124 Q207 134 198 143 L177 164 L111 98 Z"
        fill="#5F67E8"
        stroke="#11161f"
        strokeWidth="16"
      />
      <path d="M111 98 L177 164" stroke="#11161f" strokeWidth="14" />
      <path d="M48 216 H119" stroke="#4a5261" strokeWidth="16" />
    </g>
  </svg>
);

const RailButton = (props: {
  active?: boolean;
  tooltip: string;
  onClick: () => void;
  children: React.ReactNode;
}) => (
  <Tooltip content={props.tooltip} position="right">
    <Box
      p={0.6}
      mb={0.5}
      textAlign="center"
      style={{
        backgroundColor: props.active ? C.accentBg : C.bgControl,
        border: `1px solid ${props.active ? C.accentLight : '#34343f'}`,
        borderRadius: '3px',
        cursor: 'pointer',
        lineHeight: '0',
      }}
      onClick={props.onClick}
    >
      {props.children}
    </Box>
  </Tooltip>
);

const Pill = (props: { label: string; value: React.ReactNode; color?: string }) => (
  <Box
    inline
    mr={0.5}
    mb={0.5}
    px={0.7}
    py={0.3}
    style={{
      backgroundColor: C.bgControl,
      border: `1px solid ${C.borderSubtle}`,
      borderRadius: '3px',
      fontSize: '11px',
    }}
  >
    <Box inline style={{ color: C.textMuted }}>
      {props.label}{' '}
    </Box>
    <Box inline bold style={{ color: props.color || '#e0e0e0' }}>
      {props.value}
    </Box>
  </Box>
);

const Swatch = (props: { color: string }) => (
  <Box
    inline
    mr={0.4}
    width="10px"
    height="10px"
    style={{ backgroundColor: props.color, border: '1px solid #11161f', verticalAlign: 'middle' }}
  />
);

export const LiquidDebug = (props: any) => {
  const { act, data } = useBackend<Data>();
  const {
    engine,
    fluids = [],
    tool,
    paint_mode,
    brush_size,
    brush_str,
    sel_fluid,
    overlay_on,
    overlay_range,
    cell,
    pool,
    pools = [],
    pools_capped,
    source_list = [],
    source_total,
    sink_list = [],
    sink_total,
  } = data;

  const paintActive = tool === 'paint';
  const flowActive = tool === 'flow';
  const currentFluid = fluids.find((f) => f.path === sel_fluid);

  const DirButton = (dprops: { dir: number; glyph: string }) => (
    <Button
      selected={data.flow_dir_choice === dprops.dir}
      onClick={() => act('set_flow_dir_choice', { value: dprops.dir })}
      style={{ width: '26px', textAlign: 'center' }}
    >
      {dprops.glyph}
    </Button>
  );

  return (
    <Window title="Liquid Debug" width={480} height={760} theme="cellgame">
      <Window.Content scrollable>
        <Stack fill>
          {/* Tool rail */}
          <Stack.Item>
            <Box width="34px">
              <RailButton
                active={tool === 'inspect'}
                tooltip="Inspect: click a turf to examine its cell. Right-click to exit."
                onClick={() => act('set_tool', { tool: tool === 'inspect' ? 'none' : 'inspect' })}
              >
                <SelectCellIcon />
              </RailButton>
              <RailButton
                active={paintActive}
                tooltip="Paint fluid: click/drag on the map. Right-click to exit."
                onClick={() => act('set_tool', { tool: paintActive ? 'none' : 'paint' })}
              >
                <DropletIcon />
              </RailButton>
              <RailButton
                active={flowActive}
                tooltip="Flow direction: brush-paint flow modifiers, or select a whole water body and redirect it. Right-click to exit."
                onClick={() => act('set_tool', { tool: flowActive ? 'none' : 'flow' })}
              >
                <FlowIcon />
              </RailButton>
              <Box mb={0.5} style={{ borderBottom: '1px solid #34343f' }} />
              <RailButton
                active={!!overlay_on}
                tooltip="Toggle fluid-count maptext overlay around you"
                onClick={() => act('toggle_overlay')}
              >
                <Box style={{ color: overlay_on ? '#fff' : C.textMuted, fontSize: '11px', lineHeight: '20px' }} bold>
                  123
                </Box>
              </RailButton>
            </Box>
          </Stack.Item>

          {/* Main column */}
          <Stack.Item grow>
            {/* Brush */}
            <Section title="Brush" style={{ opacity: paintActive ? undefined : '0.55' }}>
              <LabeledList>
                <LabeledList.Item label="Fluid">
                  <Button selected={paint_mode === 'add'} onClick={() => act('set_paint_mode', { mode: 'add' })}>
                    Add
                  </Button>
                  <Button selected={paint_mode === 'erase'} onClick={() => act('set_paint_mode', { mode: 'erase' })}>
                    <Box inline mr={0.3} style={{ verticalAlign: 'middle', lineHeight: 0 }}>
                      <EraserIcon />
                    </Box>
                    Erase
                  </Button>
                  <Button selected={paint_mode === 'set'} onClick={() => act('set_paint_mode', { mode: 'set' })}>
                    Set
                  </Button>
                  <Button selected={paint_mode === 'clear'} onClick={() => act('set_paint_mode', { mode: 'clear' })}>
                    Clear
                  </Button>
                </LabeledList.Item>
                <LabeledList.Item label="Turf">
                  <Tooltip content="Paint turfs into spawners of the selected liquid; Str = units produced per tick">
                    <Button selected={paint_mode === 'source'} onClick={() => act('set_paint_mode', { mode: 'source' })}>
                      <Box inline style={{ color: paint_mode === 'source' ? undefined : C.success }}>
                        Source
                      </Box>
                    </Button>
                  </Tooltip>
                  <Tooltip content="Paint turfs into liquid sinks; Str = units absorbed per tick">
                    <Button selected={paint_mode === 'sink'} onClick={() => act('set_paint_mode', { mode: 'sink' })}>
                      <Box inline style={{ color: paint_mode === 'sink' ? undefined : C.error }}>
                        Sink
                      </Box>
                    </Button>
                  </Tooltip>
                  <Tooltip content="Strip source/sink status from painted turfs">
                    <Button
                      selected={paint_mode === 'endpoint_clear'}
                      onClick={() => act('set_paint_mode', { mode: 'endpoint_clear' })}
                    >
                      Neither
                    </Button>
                  </Tooltip>
                </LabeledList.Item>
                <LabeledList.Item label="Liquid">
                  <Swatch color={currentFluid?.color || C.water} />
                  <Dropdown
                    width="12em"
                    selected={sel_fluid}
                    displayText={currentFluid?.name || sel_fluid}
                    options={fluids.map((f) => ({ displayText: f.name, value: f.path }))}
                    onSelected={(value) => act('set_fluid', { path: value })}
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Size">
                  <Slider
                    value={brush_size}
                    minValue={0}
                    maxValue={6}
                    step={1}
                    onChange={(e, value) => act('set_brush_size', { value })}
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Str">
                  <Slider
                    value={brush_str}
                    minValue={1}
                    maxValue={100}
                    step={1}
                    onChange={(e, value) => act('set_brush_str', { value })}
                  />
                </LabeledList.Item>
              </LabeledList>
            </Section>

            {/* Flow */}
            <Section title="Flow" style={{ opacity: flowActive ? undefined : '0.55' }}>
              <LabeledList>
                <LabeledList.Item label="Mode">
                  <Tooltip content="Paint flow direction onto turfs with the brush (uses Size)">
                    <Button
                      selected={data.flow_apply_mode === 'brush'}
                      onClick={() => act('set_flow_mode', { mode: 'brush' })}
                    >
                      Brush
                    </Button>
                  </Tooltip>
                  <Tooltip content="Click a water tile to flood-select its whole contiguous body, then Apply">
                    <Button
                      selected={data.flow_apply_mode === 'body'}
                      onClick={() => act('set_flow_mode', { mode: 'body' })}
                    >
                      Body
                    </Button>
                  </Tooltip>
                </LabeledList.Item>
                <LabeledList.Item label="Direction">
                  <Box>
                    <DirButton dir={9} glyph="↖" />
                    <DirButton dir={1} glyph="↑" />
                    <DirButton dir={5} glyph="↗" />
                  </Box>
                  <Box>
                    <DirButton dir={8} glyph="←" />
                    <DirButton dir={0} glyph="∅" />
                    <DirButton dir={4} glyph="→" />
                  </Box>
                  <Box>
                    <DirButton dir={10} glyph="↙" />
                    <DirButton dir={2} glyph="↓" />
                    <DirButton dir={6} glyph="↘" />
                  </Box>
                </LabeledList.Item>
                {data.flow_apply_mode === 'body' && (
                  <LabeledList.Item label="Body">
                    <Pill
                      label="selected"
                      value={data.flow_selected}
                      color={data.flow_selected ? C.accentLight : C.textMuted}
                    />
                    <Button disabled={!data.flow_selected} onClick={() => act('flow_apply')}>
                      Apply
                    </Button>
                    <Button disabled={!data.flow_selected} onClick={() => act('flow_deselect')}>
                      Deselect
                    </Button>
                    {!!data.flow_capped && (
                      <Box style={{ color: '#ffe640', fontSize: '11px' }}>
                        Selection capped — body larger than the visit budget.
                      </Box>
                    )}
                  </LabeledList.Item>
                )}
              </LabeledList>
            </Section>

            {/* Simulation */}
            <Section title="Simulation">
              {engine.ready ? (
                <>
                  <Pill label="mass" value={engine.mass} color={C.water} />
                  <Pill
                    label="Δ"
                    value={engine.mass_delta}
                    color={engine.mass_delta > 0 ? C.success : engine.mass_delta < 0 ? C.error : C.textMuted}
                  />
                  <Pill label="drained" value={engine.drained} />
                  <Pill label="native active" value={engine.native_active} />
                </>
              ) : (
                <Pill label="engine" value="offline" color={C.error} />
              )}
              <Pill label="deltas" value={engine.deltas} />
              <Pill label="events" value={engine.events} />
              <Pill label="falls" value={engine.falls} />
              <Pill label="queue" value={engine.queue} />
              <Pill label="active" value={engine.cells_active} />
              <Pill label="sleeping" value={engine.cells_sleeping} />
              <Pill label="wet" value={engine.wet_turfs} />
              <Pill label="sources" value={engine.sources} color={C.success} />
              <Pill label="sinks" value={engine.sinks} color={C.error} />
              <Box mt={0.5}>
                <LabeledList>
                  <LabeledList.Item label="Overlay range">
                    <Slider
                      value={overlay_range}
                      minValue={4}
                      maxValue={20}
                      step={1}
                      onChange={(e, value) => act('set_overlay_range', { value })}
                    />
                  </LabeledList.Item>
                </LabeledList>
              </Box>
            </Section>

            {/* Cell inspector */}
            <Section
              title="Cell"
              buttons={
                <>
                  <Button onClick={() => act('inspect_here')}>Here</Button>
                  <Button disabled={!cell} onClick={() => act('jump_to_selected')}>
                    Jump
                  </Button>
                  <Button disabled={!cell} onClick={() => act('add_to_cell', { amount: brush_str })}>
                    +{brush_str}
                  </Button>
                  <Button.Confirm disabled={!cell} onClick={() => act('clear_cell')}>
                    Clear
                  </Button.Confirm>
                </>
              }
            >
              {cell ? (
                <LabeledList>
                  <LabeledList.Item label="Turf">
                    ({cell.x}, {cell.y}, {cell.z}){' '}
                    <Box inline style={{ color: C.textMuted }}>
                      {cell.turf_type}
                    </Box>
                  </LabeledList.Item>
                  <LabeledList.Item label="Fluid">
                    <Box inline bold style={{ color: C.water }}>
                      {cell.fluidsum}
                    </Box>{' '}
                    — {cell.band}
                    {cell.vis_band !== cell.band && (
                      <Box inline style={{ color: C.textMuted }}>
                        {' '}
                        (shown: {cell.vis_band})
                      </Box>
                    )}
                  </LabeledList.Item>
                  {cell.volumes.map((v) => (
                    <LabeledList.Item key={v.name} label={v.name}>
                      <Swatch color={v.color} />
                      {v.amount}
                    </LabeledList.Item>
                  ))}
                  <LabeledList.Item label="Flags">
                    {cell.is_source && (
                      <Box inline mr={1} style={{ color: C.success }}>
                        source +{cell.production_rate}
                      </Box>
                    )}
                    {cell.is_sink && (
                      <Box inline mr={1} style={{ color: C.error }}>
                        sink -{cell.absorption_rate}
                      </Box>
                    )}
                    {cell.sim_exempt && (
                      <Box inline mr={1} style={{ color: C.textMuted }}>
                        sim-exempt
                      </Box>
                    )}
                    {cell.doused && (
                      <Box inline mr={1} style={{ color: C.water }}>
                        doused
                      </Box>
                    )}
                    {!cell.is_source && !cell.is_sink && !cell.sim_exempt && !cell.doused && (
                      <Box inline style={{ color: C.textMuted }}>
                        none
                      </Box>
                    )}
                  </LabeledList.Item>
                  <LabeledList.Item label="Flow">
                    {cell.flow_dir}
                    {cell.contain_max ? ` · contain ${cell.contain_max}` : ''}
                    {cell.pressure_mask ? ` · pressure ${cell.pressure_mask}` : ''}
                  </LabeledList.Item>
                  <LabeledList.Item label="Ground">
                    wetness {cell.water_level} · drainage {cell.absorption}
                  </LabeledList.Item>
                </LabeledList>
              ) : (
                <Box style={{ color: C.textMuted }}>No cell selected — use Inspect and click a turf, or press Here.</Box>
              )}
            </Section>

            {/* Pool */}
            <Section
              title="Pool"
              buttons={
                <>
                  <Button disabled={!cell} onClick={() => act('analyze_pool')}>
                    Analyze
                  </Button>
                  <Button disabled={!cell} onClick={() => act('highlight_pool')}>
                    Highlight
                  </Button>
                </>
              }
            >
              {pool ? (
                <>
                  <Pill label="turfs" value={pool.count} />
                  <Pill label="total" value={pool.total} color={C.water} />
                  <Pill label="avg" value={pool.avg} />
                  <Pill label="min" value={pool.min} />
                  <Pill label="max" value={pool.max} />
                  <Pill label="dominant" value={pool.dominant} />
                </>
              ) : (
                <Box style={{ color: C.textMuted }}>Select a cell, then Analyze.</Box>
              )}
            </Section>

            {/* Top pools */}
            <Section title="Top Pools" buttons={<Button onClick={() => act('scan_pools')}>Scan</Button>}>
              {pools.length ? (
                <Table>
                  <Table.Row header>
                    <Table.Cell>Root</Table.Cell>
                    <Table.Cell>Turfs</Table.Cell>
                    <Table.Cell>Total</Table.Cell>
                    <Table.Cell>Avg</Table.Cell>
                    <Table.Cell />
                  </Table.Row>
                  {pools.map((p, i) => (
                    <Table.Row key={i}>
                      <Table.Cell>
                        ({p.x}, {p.y}, {p.z})
                      </Table.Cell>
                      <Table.Cell>{p.count}</Table.Cell>
                      <Table.Cell style={{ color: C.water }}>{p.total}</Table.Cell>
                      <Table.Cell>{p.avg}</Table.Cell>
                      <Table.Cell>
                        <Button onClick={() => act('select_pool', { x: p.x, y: p.y, z: p.z })}>Select</Button>
                        <Button onClick={() => act('jump_to', { x: p.x, y: p.y, z: p.z })}>Jump</Button>
                      </Table.Cell>
                    </Table.Row>
                  ))}
                </Table>
              ) : (
                <Box style={{ color: C.textMuted }}>Press Scan to enumerate pools by volume.</Box>
              )}
              {!!pools_capped && (
                <Box mt={0.5} style={{ color: '#ffe640', fontSize: '11px' }}>
                  Scan capped — large connected water (rivers/ocean) skipped after the visit budget.
                </Box>
              )}
            </Section>

            {/* Sources / sinks */}
            <Collapsible title={`Sources (${source_total})`}>
              <Table>
                {source_list.map((s, i) => (
                  <Table.Row key={i}>
                    <Table.Cell>
                      ({s.x}, {s.y}, {s.z})
                    </Table.Cell>
                    <Table.Cell style={{ color: C.success }}>+{s.rate}</Table.Cell>
                    <Table.Cell>{s.fluidsum}</Table.Cell>
                    <Table.Cell>
                      <Button onClick={() => act('jump_to', { x: s.x, y: s.y, z: s.z })}>Jump</Button>
                    </Table.Cell>
                  </Table.Row>
                ))}
              </Table>
            </Collapsible>
            <Collapsible title={`Sinks (${sink_total})`}>
              <Table>
                {sink_list.map((s, i) => (
                  <Table.Row key={i}>
                    <Table.Cell>
                      ({s.x}, {s.y}, {s.z})
                    </Table.Cell>
                    <Table.Cell style={{ color: C.error }}>-{s.rate}</Table.Cell>
                    <Table.Cell>{s.fluidsum}</Table.Cell>
                    <Table.Cell>
                      <Button onClick={() => act('jump_to', { x: s.x, y: s.y, z: s.z })}>Jump</Button>
                    </Table.Cell>
                  </Table.Row>
                ))}
              </Table>
            </Collapsible>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
