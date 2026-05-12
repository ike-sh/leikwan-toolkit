import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

const API_BASE = import.meta.env.VITE_API_BASE || '';
const tabs = ['Login', 'Dashboard', 'Topology', 'Nodes', 'Network', 'Entries', 'Forwards', 'PBR', 'DDNS', 'Events', 'Plans', 'Tasks', 'Capabilities', 'Action Catalog', 'Bootstrap', 'Settings'];
const PANEL_VERSION = '3.0.0-alpha.1';

function getOperatorToken() {
  try {
    return sessionStorage.getItem('leikwan_operator_token') || '';
  } catch {
    return '';
  }
}

function setStoredOperatorToken(token) {
  try {
    if (token) sessionStorage.setItem('leikwan_operator_token', token);
    else sessionStorage.removeItem('leikwan_operator_token');
  } catch {
    // sessionStorage may be unavailable in hardened browsers.
  }
}

function authHeaders(extra = {}) {
  const token = getOperatorToken();
  return token ? { ...extra, Authorization: `Bearer ${token}` } : extra;
}

async function apiFetch(path, options = {}) {
  const headers = authHeaders(options.headers || {});
  return fetch(`${API_BASE}${path}`, { ...options, headers });
}

async function getJSON(path) {
  const res = await apiFetch(path);
  if (!res.ok) throw new Error(errorMessage(res));
  return res.json();
}

function errorMessage(res) {
  if (res.status === 403) return '403 operator token required';
  if (res.status === 401) return '401 unauthorized';
  return `${res.status} ${res.statusText}`;
}

function usePanelData() {
  const [data, setData] = useState({ nodes: [], networkProfiles: [], entries: [], forwards: [], pbrPolicies: [], ddnsProfiles: [], events: [], loading: true, error: '' });
  useEffect(() => {
    let alive = true;
    async function load() {
      try {
        const [nodes, networkProfiles, entries, forwards, pbrPolicies, ddnsProfiles, events] = await Promise.all([
          getJSON('/api/v1/nodes'),
          getJSON('/api/v1/network-profiles'),
          getJSON('/api/v1/entries'),
          getJSON('/api/v1/forwards'),
          getJSON('/api/v1/pbr-policies'),
          getJSON('/api/v1/ddns-profiles'),
          getJSON('/api/v1/events')
        ]);
        if (alive) setData({ nodes, networkProfiles, entries, forwards, pbrPolicies, ddnsProfiles, events, loading: false, error: '' });
      } catch (err) {
        if (alive) setData((prev) => ({ ...prev, loading: false, error: err.message }));
      }
    }
    load();
    const timer = setInterval(load, 15000);
    return () => {
      alive = false;
      clearInterval(timer);
    };
  }, []);
  return data;
}

function statusCounts(nodes) {
  return nodes.reduce((acc, node) => {
    const key = node.status || 'unknown';
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {});
}

function App() {
  const [path, setPath] = useState(window.location.pathname);
  const [operatorToken, setOperatorToken] = useState(getOperatorToken());
  const [authStatus, setAuthStatus] = useState({ operator_auth_configured: false, strict_auth: false, agent_auth_configured: false, version: PANEL_VERSION });
  const data = usePanelData();
  const counts = useMemo(() => statusCounts(data.nodes), [data.nodes]);
  const active = path.startsWith('/nodes/') ? 'Node Detail' : path.startsWith('/tasks/') ? 'Task Detail' : pathToTab(path);
  function navigate(nextPath) {
    window.history.pushState({}, '', nextPath);
    setPath(nextPath);
  }
  useEffect(() => {
    const onPop = () => setPath(window.location.pathname);
    window.addEventListener('popstate', onPop);
    return () => window.removeEventListener('popstate', onPop);
  }, []);
  useEffect(() => {
    getJSON('/api/v1/auth/status')
      .then(setAuthStatus)
      .catch(() => setAuthStatus((prev) => ({ ...prev, error: 'auth status unavailable' })));
  }, [operatorToken]);
  function updateOperatorToken(token) {
    setStoredOperatorToken(token);
    setOperatorToken(token);
  }
  return (
    <div className="app">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">LQ</div>
          <div>
            <h1>Leikwan Panel</h1>
            <p>{PANEL_VERSION} demo alpha</p>
          </div>
        </div>
        <nav>
          {tabs.map((tab) => (
            <button key={tab} className={active === tab ? 'active' : ''} onClick={() => navigate(tabToPath(tab))}>
              {tab}
            </button>
          ))}
        </nav>
        <button className="disabled" disabled>Raw commands blocked</button>
      </aside>
      <main>
        <header>
          <div>
            <p className="eyebrow">Read-only operations view</p>
            <h2>{active}</h2>
          </div>
          <span className="status-pill">{data.error ? 'API error' : data.loading ? 'Loading' : 'Live'}</span>
        </header>
        <AuthBar authStatus={authStatus} token={operatorToken} onToken={updateOperatorToken} />
        {data.error && <div className="banner">API request failed: {data.error}</div>}
        <div className="notice">3.0.0-alpha.1 is a real apply alpha. Write-enabled Agents can run fixed EasyTier, nftables, PBR, DDNS and node lifecycle actions; the API still never accepts command strings or raw shell.</div>
        {active === 'Login' && <LoginPanel token={operatorToken} onToken={updateOperatorToken} />}
        {active === 'Dashboard' && <Dashboard data={data} counts={counts} onNavigate={navigate} />}
        {active === 'Topology' && <Topology />}
        {active === 'Nodes' && <Nodes nodes={data.nodes} onOpen={(id) => navigate(`/nodes/${encodeURIComponent(id)}`)} />}
        {active === 'Node Detail' && <NodeDetail nodeId={decodeURIComponent(path.split('/').pop() || '')} entries={data.entries} forwards={data.forwards} />}
        {active === 'Network' && <Network nodes={data.nodes} profiles={data.networkProfiles} />}
        {active === 'Entries' && <Entries entries={data.entries} nodes={data.nodes} profiles={data.networkProfiles} />}
        {active === 'Forwards' && <Forwards forwards={data.forwards} nodes={data.nodes} profiles={data.networkProfiles} entries={data.entries} pbrPolicies={data.pbrPolicies} />}
        {active === 'PBR' && <PBR policies={data.pbrPolicies} nodes={data.nodes} />}
        {active === 'DDNS' && <DDNS profiles={data.ddnsProfiles} nodes={data.nodes} />}
        {active === 'Events' && <Events events={data.events} />}
        {active === 'Plans' && <Plans nodes={data.nodes} />}
        {active === 'Tasks' && <Tasks nodes={data.nodes} onNavigate={navigate} />}
        {active === 'Task Detail' && <TaskDetail taskId={decodeURIComponent(path.split('/').pop() || '')} nodes={data.nodes} onNavigate={navigate} />}
        {active === 'Capabilities' && <Capabilities nodes={data.nodes} />}
        {active === 'Action Catalog' && <ActionCatalog />}
        {active === 'Bootstrap' && <Bootstrap />}
        {active === 'Settings' && <Settings authStatus={authStatus} />}
      </main>
    </div>
  );
}

function pathToTab(path) {
  if (path === '/login') return 'Login';
  if (path === '/nodes') return 'Nodes';
  if (path === '/topology') return 'Topology';
  if (path === '/network') return 'Network';
  if (path === '/entries') return 'Entries';
  if (path === '/forwards') return 'Forwards';
  if (path === '/pbr') return 'PBR';
  if (path === '/ddns') return 'DDNS';
  if (path === '/events') return 'Events';
  if (path === '/plans') return 'Plans';
  if (path === '/tasks') return 'Tasks';
  if (path === '/capabilities') return 'Capabilities';
  if (path === '/action-catalog') return 'Action Catalog';
  if (path === '/bootstrap') return 'Bootstrap';
  if (path === '/settings') return 'Settings';
  return 'Dashboard';
}

function tabToPath(tab) {
  if (tab === 'Dashboard') return '/';
  if (tab === 'Action Catalog') return '/action-catalog';
  return `/${tab.toLowerCase()}`;
}

function AuthBar({ authStatus, token, onToken }) {
  const [draft, setDraft] = useState(token || '');
  useEffect(() => setDraft(token || ''), [token]);
  function save(e) {
    e.preventDefault();
    onToken(draft.trim());
  }
  return (
    <section className="auth-bar">
      <div>
        <strong>Operator Auth</strong>
        <span>configured: {String(Boolean(authStatus.operator_auth_configured))}</span>
        <span>strict: {String(Boolean(authStatus.strict_auth))}</span>
        <span>agent auth: {String(Boolean(authStatus.agent_auth_configured))}</span>
      </div>
      <form onSubmit={save}>
        <input type="password" value={draft} onChange={(e) => setDraft(e.target.value)} placeholder="Operator token" />
        <button className="primary-action" type="submit">{token ? 'Update token' : 'Unlock'}</button>
        <button type="button" onClick={() => { setDraft(''); onToken(''); }}>Clear</button>
      </form>
      <p className="muted">Mutating APIs require the Operator token. Agent tokens cannot unlock the UI.</p>
    </section>
  );
}

function LoginPanel({ token, onToken }) {
  const [draft, setDraft] = useState(token || '');
  const [message, setMessage] = useState('');
  async function login(e) {
    e.preventDefault();
    try {
      const res = await fetch(`${API_BASE}/api/v1/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: draft.trim() })
      });
      if (!res.ok) throw new Error(errorMessage(res));
      onToken(draft.trim());
      const data = await res.json();
      setMessage(`Unlocked as ${data.identity || 'operator'}`);
    } catch (err) {
      setMessage(err.message);
    }
  }
  return (
    <section className="panel">
      <h3>Login</h3>
      <p className="muted">Leikwan Panel uses the Operator token for Web/API actions. Agent tokens cannot log in.</p>
      <form className="form-grid" onSubmit={login}>
        <label>Operator token<input type="password" value={draft} onChange={(e) => setDraft(e.target.value)} /></label>
        <button className="primary-action" type="submit">Unlock Panel</button>
      </form>
      {message && <div className="banner">{message}</div>}
    </section>
  );
}

function Settings({ authStatus }) {
  return (
    <section className="panel">
      <h3>Settings</h3>
      <KeyValue data={{
        version: PANEL_VERSION,
        operator_auth_configured: String(Boolean(authStatus.operator_auth_configured)),
        strict_auth: String(Boolean(authStatus.strict_auth)),
        agent_auth_configured: String(Boolean(authStatus.agent_auth_configured))
      }} />
      <p className="muted">3.0.0-alpha.1 keeps Shell Core independent. Web actions create fixed Agent tasks only; arbitrary command strings remain blocked.</p>
    </section>
  );
}

function Dashboard({ data, counts, onNavigate }) {
  const writeEnabled = data.nodes.filter((node) => Boolean(node.capabilities?.write_actions_supported)).length;
  return (
    <>
      <section className="metrics">
        <Metric label="Online" value={counts.online || 0} />
        <Metric label="Offline" value={counts.offline || 0} />
        <Metric label="Degraded" value={counts.degraded || 0} />
        <Metric label="Entries" value={data.entries.length} />
        <Metric label="Forwards" value={data.forwards.length} />
        <Metric label="DDNS profiles" value={data.ddnsProfiles.length} />
        <Metric label="Write-enabled agents" value={writeEnabled} />
      </section>
      <section className="action-row">
        <button className="primary-action" onClick={() => onNavigate('/topology')}>View Topology</button>
        <button className="primary-action" onClick={() => onNavigate('/bootstrap')}>Add Agent</button>
        <button className="primary-action" onClick={() => onNavigate('/network')}>Create Network</button>
      </section>
      <RecentApplyTasks />
      <section>
        <h3>Recent Status Changes</h3>
        <Events events={data.events.filter((e) => (e.message || '').includes('status changed')).slice(0, 10)} compact />
      </section>
      <section className="section-gap">
        <h3>Recent Events</h3>
        <Events events={data.events.slice(0, 10)} compact />
      </section>
    </>
  );
}

function RecentApplyTasks() {
  const [tasks, setTasks] = useState([]);
  useEffect(() => {
    let alive = true;
    getJSON('/api/v1/tasks')
      .then((items) => alive && setTasks(items.filter((task) => (task.task_group_id || '').startsWith('apply-')).slice(0, 8)))
      .catch(() => alive && setTasks([]));
    return () => { alive = false; };
  }, []);
  return (
    <section className="section-gap">
      <h3>Recent Apply Task Groups</h3>
      {tasks.length ? <TasksList tasks={tasks} nodes={[]} onOpen={() => {}} onReload={async () => {}} compact /> : <Empty text="No demo apply task groups yet" />}
    </section>
  );
}

function Topology() {
  const [topology, setTopology] = useState({ nodes: [], entries: [], forwards: [], links: [], loading: true, error: '' });
  useEffect(() => {
    let alive = true;
    getJSON('/api/v1/topology')
      .then((data) => alive && setTopology({ ...data, loading: false, error: '' }))
      .catch((err) => alive && setTopology((prev) => ({ ...prev, loading: false, error: err.message })));
    return () => { alive = false; };
  }, []);
  if (topology.loading) return <Empty text="Loading topology" />;
  if (topology.error) return <div className="banner">Topology failed: {topology.error}</div>;
  const groups = {
    entry: topology.nodes.filter((n) => n.role === 'entry'),
    relay: topology.nodes.filter((n) => n.role === 'relay' || n.role === 'mixed'),
    other: topology.nodes.filter((n) => n.role === 'unknown' || !['entry', 'relay', 'mixed'].includes(n.role))
  };
  return (
    <div className="topology-page">
      <section className="metrics">
        <Metric label="Nodes" value={topology.nodes.length} />
        <Metric label="Entries" value={topology.entries.length} />
        <Metric label="Forwards" value={topology.forwards.length} />
        <Metric label="Links" value={topology.links.length} />
      </section>
      <div className="topology-grid">
        <TopologyColumn title="Entry" nodes={groups.entry} />
        <TopologyColumn title="Relay" nodes={groups.relay} />
        <TopologyColumn title="Other / Unknown" nodes={groups.other} />
      </div>
      <section>
        <h3>Links</h3>
        {topology.links.length ? (
          <div className="link-list">
            {topology.links.map((link, idx) => (
              <div className="link-card" key={`${link.source}-${link.target}-${idx}`}>
                <span>{link.source}</span>
                <strong>{link.type}</strong>
                <span>{link.target}</span>
                <em className={`tag ${link.status}`}>{link.status || 'unknown'}</em>
              </div>
            ))}
          </div>
        ) : <Empty text="No links inferred yet" />}
      </section>
    </div>
  );
}

function TopologyColumn({ title, nodes }) {
  return (
    <section className="topology-column">
      <h3>{title}</h3>
      {nodes.length ? nodes.map((node) => (
        <div className={`node-card ${node.status}`} key={node.node_id}>
          <strong>{node.node_name || node.node_id}</strong>
          <span>{node.role}</span>
          <span>{node.public_ip || node.lan_ip || '-'}</span>
          <span className={`tag ${node.status}`}>{node.status}</span>
        </div>
      )) : <Empty text={`No ${title.toLowerCase()} nodes`} />}
    </section>
  );
}

function Bootstrap() {
  const [form, setForm] = useState({ controller_url: window.location.origin, node_name: 'leikwan-node', role: 'relay', enable_tasks: true, enable_write_actions: false, method: 'curl' });
  const [info, setInfo] = useState(null);
  const [command, setCommand] = useState({ command: '', note: '', loading: true, error: '' });
  useEffect(() => {
    let alive = true;
    getJSON('/api/v1/bootstrap/controller-info')
      .then((data) => alive && setInfo(data))
      .catch(() => alive && setInfo(null));
    return () => { alive = false; };
  }, []);
  useEffect(() => {
    let alive = true;
    const q = new URLSearchParams({
      controller_url: form.controller_url,
      node_name: form.node_name,
      role: form.role,
      enable_tasks: String(Boolean(form.enable_tasks)),
      enable_write_actions: String(Boolean(form.enable_write_actions)),
      method: form.method,
      token_mode: getOperatorToken() ? 'full' : 'masked'
    }).toString();
    getJSON(`/api/v1/bootstrap/agent-install-command?${q}`)
      .then((data) => alive && setCommand({ ...data, loading: false, error: '' }))
      .catch((err) => alive && setCommand((prev) => ({ ...prev, loading: false, error: err.message })));
    return () => { alive = false; };
  }, [form]);
  function update(key, value) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }
  return (
    <div className="bootstrap-page">
      <section className="panel">
        <h3>Add Agent / 添加节点</h3>
        <p className="muted">Agent nodes connect outward to Controller. Controller does not SSH to nodes, and Controller downtime does not stop existing forwarding.</p>
        {info && <p className="muted">Controller {info.version} at {info.controller_url_guess || info.controller_url}; script: {info.install_script_url}; demo apply: {String(Boolean(info.demo_apply))}</p>}
        <div className="form-grid">
          <label>Controller URL<input value={form.controller_url} onChange={(e) => update('controller_url', e.target.value)} /></label>
          <label>Node name<input value={form.node_name} onChange={(e) => update('node_name', e.target.value)} /></label>
          <label>Role<select value={form.role} onChange={(e) => update('role', e.target.value)}>
            {['entry', 'relay', 'mixed', 'unknown'].map((role) => <option key={role} value={role}>{role}</option>)}
          </select></label>
          <label>Install method<select value={form.method} onChange={(e) => update('method', e.target.value)}>
            <option value="curl">curl</option>
            <option value="wget">wget</option>
          </select></label>
          <label className="check-label"><input type="checkbox" checked={form.enable_tasks} onChange={(e) => update('enable_tasks', e.target.checked)} /> Enable readonly tasks</label>
          <label className="check-label"><input type="checkbox" checked={form.enable_write_actions} onChange={(e) => update('enable_write_actions', e.target.checked)} /> Enable alpha write actions</label>
        </div>
        <p className="muted">Run the generated command on the target VPS as root or with sudo. Unlock with Operator token to show the full Agent token inside the command box.</p>
      </section>
      <section className="panel">
        <h3>Install Command</h3>
        {command.error && <div className="banner">Command failed: {command.error}</div>}
        <pre className="command-box">{command.loading ? 'Loading...' : command.command}</pre>
        {command.warnings?.length ? <ul className="muted">{command.warnings.map((w) => <li key={w}>{w}</li>)}</ul> : null}
        <p className="muted">{command.note}</p>
        <div className="button-row">
          <button className="primary-action" onClick={() => navigator.clipboard.writeText(command.command || '')}>Copy command</button>
        </div>
        <p className="muted">If alpha write actions are enabled, the Agent can run only fixed allowlisted actions. No custom shell command is accepted.</p>
      </section>
    </div>
  );
}

function Network({ nodes, profiles }) {
  const relayNodes = nodes.filter((node) => node.status === 'online' && ['relay', 'mixed', 'unknown'].includes(node.role));
  const [items, setItems] = useState(profiles || []);
  const [form, setForm] = useState({ name: 'demo-network', network_name: '', relay_node_id: relayNodes[0]?.node_id || '' });
  const [error, setError] = useState('');
  useEffect(() => setItems(profiles || []), [profiles]);
  useEffect(() => {
    if (!form.relay_node_id && relayNodes[0]?.node_id) setForm((prev) => ({ ...prev, relay_node_id: relayNodes[0].node_id }));
  }, [nodes]);
  async function refresh() {
    setItems(await getJSON('/api/v1/network-profiles'));
  }
  async function create(e) {
    e.preventDefault();
    try {
      const res = await apiFetch('/api/v1/network-profiles', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form)
      });
      if (!res.ok) throw new Error(errorMessage(res));
      await refresh();
      setError('');
    } catch (err) {
      setError(err.message);
    }
  }
  async function apply(id) {
    try {
      const res = await apiFetch(`/api/v1/network-profiles/${id}/apply`, { method: 'POST' });
      if (!res.ok) throw new Error(errorMessage(res));
      setError('Network apply task queued');
    } catch (err) {
      setError(err.message);
    }
  }
  return (
    <div className="network-page">
      {error && <div className="banner">Network request failed: {error}</div>}
      <section className="panel">
        <h3>Create Network Profile</h3>
        <p className="muted">Network profiles are Controller records. The network secret is generated automatically and hidden in the UI.</p>
        <form className="form-grid" onSubmit={create}>
          <label>Name<input value={form.name} onChange={(e) => setForm((prev) => ({ ...prev, name: e.target.value }))} /></label>
          <label>Network name<input value={form.network_name} placeholder="auto-generated if empty" onChange={(e) => setForm((prev) => ({ ...prev, network_name: e.target.value }))} /></label>
          <label>Relay node<select value={form.relay_node_id} onChange={(e) => setForm((prev) => ({ ...prev, relay_node_id: e.target.value }))}>
            <option value="">Select relay node</option>
            {relayNodes.map((node) => <option key={node.node_id} value={node.node_id}>{node.node_name || node.node_id}</option>)}
          </select></label>
          <button className="primary-action" disabled={!form.relay_node_id} type="submit">Create network</button>
        </form>
      </section>
      <section>
        <h3>Network Profiles</h3>
        <NetworkTable profiles={items} onApply={apply} />
      </section>
    </div>
  );
}

function NetworkTable({ profiles, onApply }) {
  if (!profiles.length) return <Empty text="No network profiles yet" />;
  return (
    <Table headers={['ID', 'Name', 'Network name', 'Relay node', 'Secret', 'Created', 'Actions']}>
      {profiles.map((profile) => (
        <tr key={profile.id}>
          <td>{profile.id}</td>
          <td>{profile.name}</td>
          <td>{profile.network_name}</td>
          <td>{profile.relay_node_id}</td>
          <td>{profile.network_secret || 'REDACTED'}</td>
          <td>{profile.created_at}</td>
          <td>{onApply ? <button onClick={() => onApply(profile.id)}>Apply network</button> : '-'}</td>
        </tr>
      ))}
    </Table>
  );
}

function Plans({ nodes }) {
  const [plans, setPlans] = useState([]);
  const [selected, setSelected] = useState(null);
  const [form, setForm] = useState({
    type: 'create_forward',
    title: 'Create forward plan',
    target_node_id: nodes[0]?.node_id || '',
    entry: '',
    relay: '',
    target_host: '',
    target_port: '',
    protocol: 'tcp,udp'
  });
  const [error, setError] = useState('');
  useEffect(() => {
    loadPlans();
  }, []);
  useEffect(() => {
    if (!form.target_node_id && nodes[0]?.node_id) {
      setForm((prev) => ({ ...prev, target_node_id: nodes[0].node_id }));
    }
  }, [nodes]);
  async function loadPlans() {
    try {
      const data = await getJSON('/api/v1/plans');
      setPlans(data);
      setError('');
    } catch (err) {
      setError(err.message);
    }
  }
  function update(key, value) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }
  async function createPlan(e) {
    e.preventDefault();
    const payload = {
      entry: form.entry,
      relay: form.relay,
      target_host: form.target_host,
      target_port: form.target_port,
      protocol: form.protocol
    };
    try {
      const res = await apiFetch('/api/v1/plans', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: form.type,
          title: form.title,
          target_node_id: form.target_node_id,
          payload_json: payload
        })
      });
      if (!res.ok) throw new Error(errorMessage(res));
      const plan = await res.json();
      setSelected(plan);
      await loadPlans();
    } catch (err) {
      setError(err.message);
    }
  }
  return (
    <div className="plans-page">
      {error && <div className="banner">Plans request failed: {error}</div>}
      <section className="panel">
        <h3>Create Plan</h3>
        <p className="muted">Plans remain manual-first. 3.0.0-alpha.1 demo apply uses fixed alpha task actions only; no user-provided command strings are accepted.</p>
        <form className="form-grid plan-form" onSubmit={createPlan}>
          <label>Type<select value={form.type} onChange={(e) => update('type', e.target.value)}>
            {['create_entry', 'create_forward', 'switch_entry', 'ddns_check'].map((type) => <option key={type} value={type}>{type}</option>)}
          </select></label>
          <label>Title<input value={form.title} onChange={(e) => update('title', e.target.value)} /></label>
          <label>Target node<select value={form.target_node_id} onChange={(e) => update('target_node_id', e.target.value)}>
            <option value="">Select node</option>
            {nodes.map((node) => <option key={node.node_id} value={node.node_id}>{node.node_name || node.node_id}</option>)}
          </select></label>
          <label>Entry<input value={form.entry} onChange={(e) => update('entry', e.target.value)} /></label>
          <label>Relay<input value={form.relay} onChange={(e) => update('relay', e.target.value)} /></label>
          <label>Target host<input value={form.target_host} onChange={(e) => update('target_host', e.target.value)} /></label>
          <label>Target port<input value={form.target_port} onChange={(e) => update('target_port', e.target.value)} /></label>
          <label>Protocol<input value={form.protocol} onChange={(e) => update('protocol', e.target.value)} /></label>
          <button className="primary-action" type="submit">Create draft</button>
        </form>
      </section>
      <section>
        <h3>Plans</h3>
        <PlansList plans={plans} onSelect={setSelected} />
      </section>
      {selected && <PlanDetail plan={selected} onUpdate={(plan) => { setSelected(plan); loadPlans(); }} />}
    </div>
  );
}

function PlansList({ plans, onSelect }) {
  if (!plans.length) return <Empty text="No plans yet" />;
  return (
    <Table headers={['Title', 'Plan status', 'Dry-run', 'Snapshot', 'Gate', 'Execution', 'Safety', 'Class', 'Type', 'Target node', 'Updated']}>
      {plans.map((plan) => (
        <tr key={plan.id}>
          <td><button className="link-button" onClick={() => onSelect(plan)}>{plan.title}</button></td>
          <td><span className={`tag ${plan.status}`}>{plan.status}</span></td>
          <td><span className={`tag ${plan.dry_run_status}`}>{plan.dry_run_status || 'not_run'}</span></td>
          <td><span className={`tag ${plan.snapshot_status}`}>{plan.snapshot_status || 'missing'}</span></td>
          <td><span className={`tag ${planGateLabel(plan)}`}>{planGateLabel(plan)}</span></td>
          <td><span className={`tag ${plan.execution_status}`}>{plan.execution_status || 'not_run'}</span></td>
          <td><span className={`tag ${plan.safety_level}`}>{plan.safety_level || 'safe'}</span></td>
          <td><span className={`tag ${plan.command_classification}`}>{plan.command_classification || 'manual'}</span></td>
          <td>{plan.type}</td>
          <td>{plan.target_node_id || '-'}</td>
          <td>{plan.updated_at || plan.created_at}</td>
        </tr>
      ))}
    </Table>
  );
}

function planGateLabel(plan) {
  if ((plan.dry_run_status || 'not_run') !== 'passed') return 'blocked';
  if ((plan.snapshot_policy || 'recommended') === 'required' && !['recorded', 'verified'].includes(plan.snapshot_status || 'missing')) return 'blocked';
  if ((plan.snapshot_policy || 'recommended') === 'required' && !plan.rollback_available) return 'blocked';
  if ((plan.snapshot_policy || 'recommended') === 'recommended' && !['recorded', 'verified'].includes(plan.snapshot_status || 'missing')) return 'warning';
  return 'ready';
}

function PlanDetail({ plan, onUpdate }) {
  const [copyText, setCopyText] = useState('');
  const [manualNote, setManualNote] = useState(plan.execution_note || '');
  const [snapshot, setSnapshot] = useState({ snapshot_ref: plan.snapshot_ref || '', snapshot_note: plan.snapshot_note || '' });
  const [rollback, setRollback] = useState({ rollback_ref: plan.rollback_ref || '', rollback_note: plan.rollback_note || '' });
  const [metadata, setMetadata] = useState({
    note: '',
    snapshot_ref: plan.snapshot_ref || '',
    snapshot_note: plan.snapshot_note || '',
    rollback_ref: plan.rollback_ref || '',
    rollback_note: plan.rollback_note || '',
    execution_status: 'succeeded',
    verification_status: 'passed',
    evidence_type: 'manual',
    title: '',
    content: ''
  });
  const [evidence, setEvidence] = useState([]);
  const [safetyGate, setSafetyGate] = useState(null);
  const [actionReview, setActionReview] = useState(null);
  const [checked, setChecked] = useState({});
  const markdownText = plan.markdown || 'Generate the plan to create the manual execution guide.';
  useEffect(() => {
    setManualNote(plan.execution_note || '');
    setSnapshot({ snapshot_ref: plan.snapshot_ref || '', snapshot_note: plan.snapshot_note || '' });
    setRollback({ rollback_ref: plan.rollback_ref || '', rollback_note: plan.rollback_note || '' });
    setMetadata({
      note: '',
      snapshot_ref: plan.snapshot_ref || '',
      snapshot_note: plan.snapshot_note || '',
      rollback_ref: plan.rollback_ref || '',
      rollback_note: plan.rollback_note || '',
      execution_status: 'succeeded',
      verification_status: 'passed',
      evidence_type: 'manual',
      title: '',
      content: ''
    });
    setEvidence([]);
    setChecked({});
    setCopyText('');
    setSafetyGate(null);
    setActionReview(null);
  }, [plan.id]);
  useEffect(() => {
    loadEvidence();
  }, [plan.id]);
  async function loadEvidence() {
    try {
      setEvidence(await getJSON(`/api/v1/plans/${plan.id}/evidence`));
    } catch {
      setEvidence([]);
    }
  }
  async function generate() {
    const res = await apiFetch(`/api/v1/plans/${plan.id}/generate`, { method: 'POST' });
    if (!res.ok) throw new Error(errorMessage(res));
    onUpdate(await res.json());
  }
  async function regenerate() {
    const res = await apiFetch(`/api/v1/plans/${plan.id}/regenerate`, { method: 'POST' });
    if (!res.ok) throw new Error(errorMessage(res));
    onUpdate(await res.json());
  }
  async function preflight() {
    const res = await apiFetch(`/api/v1/plans/${plan.id}/preflight`, { method: 'POST' });
    if (!res.ok) throw new Error(errorMessage(res));
    onUpdate(await res.json());
  }
  async function startDryRun() {
    if (!window.confirm('This only creates readonly tasks and does not apply changes. Start dry-run?')) {
      return;
    }
    const res = await apiFetch(`/api/v1/plans/${plan.id}/dry-run`, { method: 'POST' });
    if (!res.ok) throw new Error(errorMessage(res));
    onUpdate(await res.json());
  }
  async function refreshDryRun() {
    const res = await apiFetch(`/api/v1/plans/${plan.id}/dry-run`);
    if (!res.ok) throw new Error(errorMessage(res));
    onUpdate(await res.json());
  }
  async function recordSnapshot(e) {
    e.preventDefault();
    const res = await apiFetch(`/api/v1/plans/${plan.id}/snapshot`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(snapshot)
    });
    if (!res.ok) throw new Error(errorMessage(res));
    onUpdate(await res.json());
  }
  async function recordRollback(e) {
    e.preventDefault();
    const res = await apiFetch(`/api/v1/plans/${plan.id}/rollback-info`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...rollback, rollback_available: Boolean(rollback.rollback_ref || rollback.rollback_note) })
    });
    if (!res.ok) throw new Error(errorMessage(res));
    onUpdate(await res.json());
  }
  async function refreshSafetyGate() {
    const gate = await getJSON(`/api/v1/plans/${plan.id}/safety-gate`);
    setSafetyGate(gate);
  }
  async function verifyPlan() {
    const res = await apiFetch(`/api/v1/plans/${plan.id}/verify`, { method: 'POST' });
    if (!res.ok) throw new Error(errorMessage(res));
    onUpdate(await res.json());
    await refreshSafetyGate();
  }
  async function refreshActionReview() {
    const review = await getJSON(`/api/v1/plans/${plan.id}/action-review`);
    setActionReview(review);
  }
  async function metadataAction(action, extra = {}) {
    const res = await apiFetch(`/api/v1/plans/${plan.id}/metadata-action`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action, note: metadata.note, ...extra })
    });
    if (!res.ok) throw new Error(errorMessage(res));
    const updated = await res.json();
    onUpdate(updated);
    await loadEvidence();
    await refreshSafetyGate();
  }
  async function attachEvidence(e) {
    e.preventDefault();
    await metadataAction('attach_manual_evidence', {
      evidence_type: metadata.evidence_type,
      title: metadata.title,
      content: metadata.content
    });
    setMetadata((prev) => ({ ...prev, title: '', content: '', note: '' }));
  }
  async function archive() {
    const res = await apiFetch(`/api/v1/plans/${plan.id}/archive`, { method: 'POST' });
    if (!res.ok) throw new Error(errorMessage(res));
    onUpdate(await res.json());
  }
  async function mark(status) {
    const res = await apiFetch(`/api/v1/plans/${plan.id}/mark`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        execution_status: status,
        execution_note: manualNote,
        manual_result: JSON.stringify({ checked })
      })
    });
    if (!res.ok) throw new Error(errorMessage(res));
    onUpdate(await res.json());
  }
  async function copyCommands() {
    if (plan.safety_level === 'dangerous' && !window.confirm('This plan is marked dangerous. Copy commands anyway?')) {
      return;
    }
    const text = commandsFromGroups(plan).join('\n');
    try {
      await navigator.clipboard.writeText(text);
      setCopyText('Copied');
    } catch {
      setCopyText('Copy failed');
    }
  }
  async function copyMarkdown() {
    try {
      await navigator.clipboard.writeText(markdownText);
      setCopyText('Markdown copied');
    } catch {
      setCopyText('Copy failed');
    }
  }
  function toggleCheck(idx) {
    setChecked((prev) => ({ ...prev, [idx]: !prev[idx] }));
  }
  return (
    <section className="panel">
      <h3>Plan Detail</h3>
      <dl className="kv">
        <dt>Title</dt><dd>{plan.title}</dd>
        <dt>Type</dt><dd>{plan.type}</dd>
        <dt>Status</dt><dd>{plan.status}</dd>
        <dt>Dry-run</dt><dd><span className={`tag ${plan.dry_run_status}`}>{plan.dry_run_status || 'not_run'}</span></dd>
        <dt>Snapshot</dt><dd><span className={`tag ${plan.snapshot_status}`}>{plan.snapshot_policy || 'recommended'} / {plan.snapshot_status || 'missing'}</span></dd>
        <dt>Verification</dt><dd><span className={`tag ${plan.verification_status}`}>{plan.verification_status || 'not_run'}</span></dd>
        <dt>Execution</dt><dd><span className={`tag ${plan.execution_status}`}>{plan.execution_status || 'not_run'}</span></dd>
        <dt>Safety</dt><dd><span className={`tag ${plan.safety_level}`}>{plan.safety_level || 'safe'}</span></dd>
        <dt>Command class</dt><dd><span className={`tag ${plan.command_classification}`}>{plan.command_classification || 'manual'}</span></dd>
        <dt>Target</dt><dd>{plan.target_node_id || '-'}</dd>
      </dl>
      {plan.safety_level === 'dangerous' && <div className="danger-banner">Dangerous plan: blocked command text was removed. Review preflight before copying anything.</div>}
      <h4>Payload</h4>
      <pre className="command-box">{JSON.stringify(plan.payload_json || {}, null, 2)}</pre>
      <h4>Warnings</h4>
      <List items={plan.warnings || []} empty="No warnings generated yet" />
      <h4>Preflight</h4>
      <Preflight data={plan.preflight} />
      <h4>Readonly Dry-run</h4>
      <DryRun plan={plan} onStart={startDryRun} onRefresh={refreshDryRun} />
      <h4>Snapshot / Rollback</h4>
      <SnapshotRollback plan={plan} snapshot={snapshot} rollback={rollback} setSnapshot={setSnapshot} setRollback={setRollback} onSnapshot={recordSnapshot} onRollback={recordRollback} />
      <h4>Safety Gate</h4>
      <SafetyGate gate={safetyGate} plan={plan} onRefresh={refreshSafetyGate} onVerify={verifyPlan} />
      <h4>Action Review</h4>
      <ActionReview review={actionReview} plan={plan} onRefresh={refreshActionReview} />
      <h4>Metadata Actions / Manual Evidence</h4>
      <MetadataActions
        plan={plan}
        metadata={metadata}
        setMetadata={setMetadata}
        evidence={evidence}
        onSnapshot={() => metadataAction('record_snapshot_ref', { snapshot_ref: metadata.snapshot_ref, snapshot_note: metadata.snapshot_note })}
        onRollback={() => metadataAction('record_rollback_ref', { rollback_ref: metadata.rollback_ref, rollback_note: metadata.rollback_note })}
        onExecuted={() => metadataAction('mark_plan_executed', { execution_status: metadata.execution_status })}
        onVerified={() => metadataAction('mark_plan_verified', { verification_status: metadata.verification_status })}
        onEvidence={attachEvidence}
      />
      <h4>Capability Requirements</h4>
      <List items={plan.capability_requirements || []} empty="No requirements generated yet" />
      <h4>Checklist</h4>
      <Checklist items={plan.checklist || []} checked={checked} onToggle={toggleCheck} />
      <h4>Command Groups</h4>
      <CommandGroups groups={plan.command_groups || []} fallback={plan.generated_commands || []} />
      <h4>Markdown Preview</h4>
      <pre className="command-box markdown-preview">{markdownText}</pre>
      <h4>Manual Result</h4>
      <textarea className="note-box" value={manualNote} onChange={(e) => setManualNote(e.target.value)} placeholder="Optional note after manual SSH execution" />
      <div className="action-row">
        <button className="primary-action" onClick={generate}>Generate guide</button>
        <button className="primary-action" onClick={regenerate}>Regenerate</button>
        <button className="primary-action" onClick={preflight}>Run preflight</button>
        <button className="primary-action" onClick={startDryRun}>Start dry-run</button>
        <button className="link-button" onClick={refreshDryRun}>Refresh dry-run</button>
        <button className="link-button" onClick={refreshSafetyGate}>Refresh safety gate</button>
        <button className="link-button" onClick={refreshActionReview}>Review future action</button>
        <button className="link-button" onClick={verifyPlan}>Verify plan</button>
        <button className="primary-action" onClick={copyCommands} disabled={!commandsFromGroups(plan).length}>Copy commands</button>
        <button className="primary-action" onClick={copyMarkdown} disabled={!plan.markdown}>Copy markdown</button>
        <button className="link-button" onClick={() => mark('running_manually')}>Mark running</button>
        <button className="link-button" onClick={() => mark('succeeded')}>Mark succeeded</button>
        <button className="link-button" onClick={() => mark('failed')}>Mark failed</button>
        <button className="link-button" onClick={() => mark('rolled_back')}>Mark rolled back</button>
        <button className="disabled inline" disabled>Node execution blocked</button>
        <button className="link-button" onClick={archive}>Archive</button>
        {copyText && <span className="muted">{copyText}</span>}
      </div>
    </section>
  );
}

function MetadataActions({ plan, metadata, setMetadata, evidence, onSnapshot, onRollback, onExecuted, onVerified, onEvidence }) {
  function update(key, value) {
    setMetadata((prev) => ({ ...prev, [key]: value }));
  }
  return (
    <div className="metadata-actions">
      <p className="muted">These actions only update Controller audit metadata. They do not modify nodes, execute commands, create Agent tasks, create snapshots, run rollback, switch entries, restart relay, or change Leikwan Core configuration.</p>
      <div className="kv">
        <span>Executed by</span><strong>{plan.executed_by || '-'}</strong>
        <span>Executed at</span><strong>{plan.executed_at || '-'}</strong>
        <span>Verified by</span><strong>{plan.verified_by || '-'}</strong>
        <span>Verified at</span><strong>{plan.verified_at || '-'}</strong>
      </div>
      <label>Shared note<textarea value={metadata.note} onChange={(e) => update('note', e.target.value)} placeholder="Redacted operator note for timeline/event audit" /></label>
      <div className="split-grid">
        <div className="mini-form">
          <h5>Record snapshot ref</h5>
          <label>Snapshot ref<input value={metadata.snapshot_ref} onChange={(e) => update('snapshot_ref', e.target.value)} placeholder="snapshot-YYYYMMDD-HHMMSS.tar.gz" /></label>
          <label>Snapshot note<textarea value={metadata.snapshot_note} onChange={(e) => update('snapshot_note', e.target.value)} placeholder="Manual snapshot note" /></label>
          <button className="primary-action" type="button" onClick={onSnapshot}>Record snapshot ref</button>
        </div>
        <div className="mini-form">
          <h5>Record rollback ref</h5>
          <label>Rollback ref<input value={metadata.rollback_ref} onChange={(e) => update('rollback_ref', e.target.value)} placeholder="rollback path / old state reference" /></label>
          <label>Rollback note<textarea value={metadata.rollback_note} onChange={(e) => update('rollback_note', e.target.value)} placeholder="Manual rollback note" /></label>
          <button className="primary-action" type="button" onClick={onRollback}>Record rollback ref</button>
        </div>
        <div className="mini-form">
          <h5>Manual execution</h5>
          <label>Status<select value={metadata.execution_status} onChange={(e) => update('execution_status', e.target.value)}>
            {['running_manually', 'succeeded', 'failed', 'rolled_back'].map((status) => <option key={status} value={status}>{status}</option>)}
          </select></label>
          <button className="primary-action" type="button" onClick={onExecuted}>Mark manually executed</button>
        </div>
        <div className="mini-form">
          <h5>Manual verification</h5>
          <label>Status<select value={metadata.verification_status} onChange={(e) => update('verification_status', e.target.value)}>
            {['passed', 'warning', 'failed'].map((status) => <option key={status} value={status}>{status}</option>)}
          </select></label>
          <button className="primary-action" type="button" onClick={onVerified}>Mark manually verified</button>
        </div>
      </div>
      <form className="mini-form evidence-form" onSubmit={onEvidence}>
        <h5>Attach manual evidence</h5>
        <label>Evidence type<input value={metadata.evidence_type} onChange={(e) => update('evidence_type', e.target.value)} placeholder="manual" /></label>
        <label>Title<input value={metadata.title} onChange={(e) => update('title', e.target.value)} placeholder="Post-change status output" /></label>
        <label>Content<textarea value={metadata.content} onChange={(e) => update('content', e.target.value)} placeholder="Paste redacted manual evidence. Secrets are redacted again by Controller." /></label>
        <button className="primary-action" type="submit">Attach manual evidence</button>
      </form>
      <h5>Evidence</h5>
      {evidence.length ? (
        <Table headers={['Type', 'Title', 'Created by', 'Created at', 'Content']}>
          {evidence.map((item) => (
            <tr key={item.id}>
              <td>{item.evidence_type}</td>
              <td>{item.title}</td>
              <td>{item.created_by}</td>
              <td>{item.created_at}</td>
              <td><pre className="inline-pre">{item.redacted_content || item.content || '-'}</pre></td>
            </tr>
          ))}
        </Table>
      ) : <Empty text="No manual evidence attached yet" />}
    </div>
  );
}

function commandsFromGroups(plan) {
  if (plan.command_groups?.length) {
    return plan.command_groups.flatMap((group) => [
      `# On ${group.role || 'unknown'} node: ${group.node_name || group.node_id || '-'}`,
      ...(group.commands || [])
    ]);
  }
  return plan.generated_commands || [];
}

function Checklist({ items, checked, onToggle }) {
  if (!items.length) return <Empty text="Generate the plan to create a checklist" />;
  return (
    <div className="checklist">
      {items.map((item, idx) => (
        <label key={`${item}-${idx}`}>
          <input type="checkbox" checked={Boolean(checked[idx])} onChange={() => onToggle(idx)} />
          <span>{item}</span>
        </label>
      ))}
    </div>
  );
}

function CommandGroups({ groups, fallback }) {
  if (groups.length) {
    return (
      <div className="command-groups">
        {groups.map((group, idx) => (
          <div key={`${group.node_id}-${idx}`} className="command-group">
            <h5>{group.node_name || group.node_id || 'target node'} <span className={`tag ${group.role}`}>{group.role || 'unknown'}</span></h5>
            <pre className="command-box">{(group.commands || []).join('\n')}</pre>
          </div>
        ))}
      </div>
    );
  }
  return <pre className="command-box">{fallback.join('\n') || 'Generate the plan to create manual commands.'}</pre>;
}

function Preflight({ data }) {
  const value = objectOrEmpty(data);
  const checks = arrayOrEmpty(value.checks);
  if (!checks.length) return <Empty text="Run preflight or generate the plan to create checks" />;
  return (
    <div className="preflight">
      <p>Overall: <span className={`tag ${value.overall === 'ok' ? 'safe' : 'caution'}`}>{value.overall || 'unknown'}</span></p>
      {checks.map((check, idx) => (
        <div className={`preflight-row ${check.ok ? 'ok' : 'warn'}`} key={`${check.name}-${idx}`}>
          <span>{check.ok ? 'OK' : 'WARN'}</span>
          <strong>{check.name}</strong>
          <em>{check.message || '-'}</em>
        </div>
      ))}
    </div>
  );
}

function DryRun({ plan, onStart, onRefresh }) {
  const report = objectOrEmpty(plan.dry_run_report);
  const tasks = arrayOrEmpty(report.tasks);
  const warnings = arrayOrEmpty(report.warnings);
  const doctorWarnings = arrayOrEmpty(report.doctor_warnings);
  return (
    <div className="dry-run">
      <p className="muted">This only creates readonly tasks and does not apply changes.</p>
      <div className="kv">
        <span>Status</span><strong><span className={`tag ${plan.dry_run_status}`}>{plan.dry_run_status || 'not_run'}</span></strong>
        <span>Last run</span><strong>{plan.last_dry_run_at || '-'}</strong>
        <span>Task IDs</span><strong>{(plan.dry_run_task_ids || []).join(', ') || '-'}</strong>
        <span>Recommendation</span><strong>{report.recommendation || '-'}</strong>
      </div>
      <div className="button-row">
        <button className="primary-action" onClick={onStart}>Start dry-run</button>
        <button className="link-button" onClick={onRefresh} disabled={!(plan.dry_run_task_ids || []).length}>Refresh report</button>
      </div>
      <h5>Dry-run report</h5>
      <pre className="command-box">{JSON.stringify(report, null, 2)}</pre>
      {tasks.length > 0 && (
        <>
          <h5>Linked readonly tasks</h5>
          <Table headers={['Task', 'Action', 'Status', 'Exit', 'Error']}>
            {tasks.map((task) => (
              <tr key={task.id}>
                <td>{task.id}</td>
                <td>{task.action}</td>
                <td><span className={`tag ${task.status}`}>{task.status}</span></td>
                <td>{task.exit_code}</td>
                <td>{task.error || '-'}</td>
              </tr>
            ))}
          </Table>
        </>
      )}
      <List title="Warnings" items={[...warnings, ...doctorWarnings]} empty="No dry-run warnings" />
    </div>
  );
}

function SnapshotRollback({ plan, snapshot, rollback, setSnapshot, setRollback, onSnapshot, onRollback }) {
  return (
    <div className="snapshot-rollback">
      <p className="muted">3.0.0-alpha.1 records manual snapshot and rollback information. Demo apply does not create snapshots or run rollback.</p>
      <div className="kv">
        <span>Snapshot policy</span><strong>{plan.snapshot_policy || 'recommended'}</strong>
        <span>Snapshot status</span><strong><span className={`tag ${plan.snapshot_status}`}>{plan.snapshot_status || 'missing'}</span></strong>
        <span>Snapshot ref</span><strong>{plan.snapshot_ref || '-'}</strong>
        <span>Rollback available</span><strong>{String(Boolean(plan.rollback_available))}</strong>
        <span>Rollback ref</span><strong>{plan.rollback_ref || '-'}</strong>
      </div>
      <div className="split-grid">
        <form className="mini-form" onSubmit={onSnapshot}>
          <h5>Record snapshot</h5>
          <label>Snapshot ref<input value={snapshot.snapshot_ref} onChange={(e) => setSnapshot((prev) => ({ ...prev, snapshot_ref: e.target.value }))} placeholder="snapshot-20260512-120000.tar.gz" /></label>
          <label>Snapshot note<textarea value={snapshot.snapshot_note} onChange={(e) => setSnapshot((prev) => ({ ...prev, snapshot_note: e.target.value }))} placeholder="Operator, location, or manual verification note" /></label>
          <button className="primary-action" type="submit">Record snapshot metadata</button>
        </form>
        <form className="mini-form" onSubmit={onRollback}>
          <h5>Record rollback info</h5>
          <label>Rollback ref<input value={rollback.rollback_ref} onChange={(e) => setRollback((prev) => ({ ...prev, rollback_ref: e.target.value }))} placeholder="rollback note / old state reference" /></label>
          <label>Rollback note<textarea value={rollback.rollback_note} onChange={(e) => setRollback((prev) => ({ ...prev, rollback_note: e.target.value }))} placeholder="How to manually restore the previous state" /></label>
          <button className="primary-action" type="submit">Record rollback metadata</button>
        </form>
      </div>
      <h5>Rollback instructions</h5>
      <pre className="command-box">{plan.rollback_instructions || 'Generate the plan to create rollback instructions.'}</pre>
    </div>
  );
}

function SafetyGate({ gate, plan, onRefresh, onVerify }) {
  const fallback = {
    dry_run_passed: (plan.dry_run_status || 'not_run') === 'passed',
    approval_ready: (plan.safety_level || 'safe') !== 'dangerous' && (plan.command_classification || 'manual') !== 'blocked',
    snapshot_ready: ['not_required', 'recorded', 'verified'].includes(plan.snapshot_status || 'missing'),
    rollback_ready: Boolean(plan.rollback_available || plan.rollback_ref || plan.rollback_instructions),
    blocked_reasons: [],
    warnings: ['Refresh safety gate for Controller-side checks.'],
    overall: planGateLabel(plan)
  };
  const value = gate || fallback;
  return (
    <div className="safety-gate">
      <p className="muted">Safety Gate is an audit checklist, not execution permission. It does not contact Agents or change nodes.</p>
      <div className="kv">
        <span>Overall</span><strong><span className={`tag ${value.overall}`}>{value.overall}</span></strong>
        <span>Dry-run passed</span><strong>{String(Boolean(value.dry_run_passed))}</strong>
        <span>Approval ready</span><strong>{String(Boolean(value.approval_ready))}</strong>
        <span>Snapshot ready</span><strong>{String(Boolean(value.snapshot_ready))}</strong>
        <span>Rollback ready</span><strong>{String(Boolean(value.rollback_ready))}</strong>
      </div>
      <List title="Blocked reasons" items={value.blocked_reasons || []} empty="No blocked reasons" />
      <List title="Warnings" items={value.warnings || []} empty="No warnings" />
      <h5>Verification report</h5>
      <pre className="command-box">{JSON.stringify(objectOrEmpty(plan.verification_report), null, 2)}</pre>
      <div className="button-row">
        <button className="link-button" onClick={onRefresh}>Refresh safety gate</button>
        <button className="link-button" onClick={onVerify}>Verify from current Controller state</button>
      </div>
    </div>
  );
}

function ActionReview({ review, plan, onRefresh }) {
  const value = review || {
    matched_action: plan.type || '-',
    category: 'future_write_guarded',
    risk_level: 'unknown',
    required_gates: [],
    required_capabilities: [],
    missing_gates: ['refresh action review'],
    ready_for_future_execution: false,
    reason: 'Refresh action review for Controller-side checks.'
  };
  return (
    <div className="action-review">
      <p className="muted">3.0.0-alpha.1 reviews future node writes separately from demo apply. The review does not generate command strings or bypass safety gates.</p>
      <div className="kv">
        <span>Matched action</span><strong>{value.matched_action}</strong>
        <span>Category</span><strong><span className={`tag ${value.category}`}>{value.category}</span></strong>
        <span>Risk level</span><strong><span className={`tag ${value.risk_level}`}>{value.risk_level}</span></strong>
        <span>Enabled</span><strong>{String(Boolean(value.enabled))}</strong>
        <span>Ready for future execution</span><strong>{String(Boolean(value.ready_for_future_execution))}</strong>
        <span>Reason</span><strong>{value.reason || '-'}</strong>
      </div>
      <List title="Required gates" items={value.required_gates || []} empty="No gates required" />
      <List title="Missing gates" items={value.missing_gates || []} empty="No missing gates" />
      <List title="Required capabilities" items={value.required_capabilities || []} empty="No capability requirements" />
      <div className="button-row">
        <button className="link-button" onClick={onRefresh}>Refresh action review</button>
        <button className="disabled inline" disabled>Future node writes disabled</button>
      </div>
    </div>
  );
}

const readonlyActions = [
  'probe_core_version',
  'run_status',
  'run_status_json',
  'run_doctor',
  'run_doctor_json',
  'list_forwards',
  'ddns_overview'
];

const alphaWriteActions = [
  'configure_node_role',
  'apply_network_profile',
  'apply_entry_config',
  'apply_forward_config',
  'reload_leikwan_core',
  'verify_applied_config'
];

function Tasks({ nodes, onNavigate }) {
  const [tasks, setTasks] = useState([]);
  const [form, setForm] = useState({ node_id: nodes[0]?.node_id || '', action: 'run_status_json' });
  const [error, setError] = useState('');
  useEffect(() => {
    loadTasks();
  }, []);
  useEffect(() => {
    if (!form.node_id && nodes[0]?.node_id) {
      setForm((prev) => ({ ...prev, node_id: nodes[0].node_id }));
    }
  }, [nodes]);
  async function loadTasks() {
    try {
      setTasks(await getJSON('/api/v1/tasks'));
      setError('');
    } catch (err) {
      setError(err.message);
    }
  }
  async function createTask(e) {
    e.preventDefault();
    try {
      const res = await apiFetch('/api/v1/tasks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form)
      });
      if (!res.ok) throw new Error(errorMessage(res));
      await loadTasks();
    } catch (err) {
      setError(err.message);
    }
  }
  return (
    <div className="tasks-page">
      {error && <div className="banner">Tasks request failed: {error}</div>}
      <section className="panel">
        <h3>Create Readonly Task</h3>
        <p className="muted">3.0.0-alpha.1 queues builtin readonly actions here. Demo apply pages create alpha write tasks automatically for write-enabled Agents; the API never accepts command strings.</p>
        <form className="form-grid" onSubmit={createTask}>
          <label>Node<select value={form.node_id} onChange={(e) => setForm((prev) => ({ ...prev, node_id: e.target.value }))}>
            <option value="">Select node</option>
            {nodes.map((node) => <option key={node.node_id} value={node.node_id}>{node.node_name || node.node_id}</option>)}
          </select></label>
          <label>Action<select value={form.action} onChange={(e) => setForm((prev) => ({ ...prev, action: e.target.value }))}>
            {readonlyActions.map((action) => <option key={action} value={action}>{action}</option>)}
          </select></label>
          <button className="primary-action" type="submit" disabled={!form.node_id}>Queue readonly task</button>
          <button className="disabled inline" disabled>Arbitrary commands blocked</button>
        </form>
      </section>
      <section>
        <h3>Tasks</h3>
        <TasksList tasks={tasks} nodes={nodes} onOpen={(id) => onNavigate(`/tasks/${encodeURIComponent(id)}`)} onReload={loadTasks} />
      </section>
    </div>
  );
}

async function postTaskAction(id, action, body = {}) {
  const res = await apiFetch(`/api/v1/tasks/${id}/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  if (!res.ok) throw new Error(errorMessage(res));
  return res.json();
}

function TasksList({ tasks, nodes, onOpen, onReload }) {
  if (!tasks.length) return <Empty text="No tasks queued yet" />;
  const names = Object.fromEntries(nodes.map((node) => [node.node_id, node.node_name || node.node_id]));
  async function act(id, action) {
    await postTaskAction(id, action, { actor: 'panel-ui' });
    await onReload();
  }
  return (
    <Table headers={['ID', 'Node', 'Action', 'Group', 'Class', 'Status', 'Approval', 'Attempt', 'Created', 'Expires', 'Picked', 'Finished', 'Result', 'Actions']}>
      {tasks.map((task) => (
        <tr key={task.id}>
          <td><button className="link-button" onClick={() => onOpen(task.id)}>{task.id}</button></td>
          <td>{names[task.node_id] || task.node_id}</td>
          <td>{task.action}</td>
          <td>{task.task_group_id || '-'}</td>
          <td><span className={`tag ${alphaWriteActions.includes(task.action) ? 'alpha_write' : 'readonly'}`}>{alphaWriteActions.includes(task.action) ? 'alpha write' : 'readonly'}</span></td>
          <td><span className={`tag ${task.status}`}>{task.status}</span></td>
          <td><span className={`tag ${task.approval_status}`}>{task.approval_status || 'not_required'}</span></td>
          <td>{task.attempt || 1}/{task.max_attempts || 3}{task.retry_of_task_id ? ` of #${task.retry_of_task_id}` : ''}</td>
          <td>{task.created_at || '-'}</td>
          <td>{task.expires_at || '-'}</td>
          <td>{task.picked_at || '-'}</td>
          <td>{task.finished_at || '-'}</td>
          <td>
            {(task.result_stdout || task.result_stderr) ? (
              <details className="task-result">
                <summary>View redacted output</summary>
                {task.result_stdout && <pre>{task.result_stdout}</pre>}
                {task.result_stderr && <pre>{task.result_stderr}</pre>}
              </details>
            ) : '-'}
          </td>
          <td className="button-row compact">
            <button onClick={() => onOpen(task.id)}>Details</button>
            <button onClick={() => act(task.id, 'cancel')} disabled={!['queued', 'picked'].includes(task.status)}>Cancel</button>
            <button onClick={() => act(task.id, 'retry')} disabled={!['failed', 'expired', 'canceled'].includes(task.status)}>Retry</button>
          </td>
        </tr>
      ))}
    </Table>
  );
}

function TaskDetail({ taskId, nodes, onNavigate }) {
  const [state, setState] = useState({ task: null, timeline: [], loading: true, error: '' });
  const names = Object.fromEntries(nodes.map((node) => [node.node_id, node.node_name || node.node_id]));
  async function load() {
    try {
      const [task, timeline] = await Promise.all([
        getJSON(`/api/v1/tasks/${encodeURIComponent(taskId)}`),
        getJSON(`/api/v1/tasks/${encodeURIComponent(taskId)}/timeline`)
      ]);
      setState({ task, timeline, loading: false, error: '' });
    } catch (err) {
      setState((prev) => ({ ...prev, loading: false, error: err.message }));
    }
  }
  useEffect(() => {
    load();
  }, [taskId]);
  async function act(action) {
    try {
      await postTaskAction(taskId, action, { actor: 'panel-ui' });
      await load();
    } catch (err) {
      setState((prev) => ({ ...prev, error: err.message }));
    }
  }
  async function copyResult() {
    const task = state.task || {};
    await navigator.clipboard.writeText([task.result_stdout || '', task.result_stderr || '', task.error || ''].filter(Boolean).join('\n'));
  }
  if (state.loading) return <Empty text="Loading task detail" />;
  if (state.error && !state.task) return <div className="banner">Task detail failed: {state.error}</div>;
  const task = state.task;
  const node = nodes.find((item) => item.node_id === task.node_id);
  return (
    <div className="detail task-detail">
      {state.error && <div className="banner">Task action failed: {state.error}</div>}
      <section className="panel">
        <button className="link-button" onClick={() => onNavigate('/tasks')}>Back to Tasks</button>
        <h3>Task #{task.id}</h3>
        <div className="kv">
          <span>Node</span><strong>{names[task.node_id] || task.node_id}</strong>
          <span>Role</span><strong>{node?.role || '-'}</strong>
          <span>Action</span><strong>{task.action}</strong>
          <span>Classification</span><strong><span className={`tag ${alphaWriteActions.includes(task.action) ? 'alpha_write' : 'readonly'}`}>{alphaWriteActions.includes(task.action) ? 'alpha write' : 'readonly'}</span></strong>
          <span>Status</span><strong><span className={`tag ${task.status}`}>{task.status}</span></strong>
          <span>Approval</span><strong><span className={`tag ${task.approval_status}`}>{task.approval_status || 'not_required'}</span></strong>
          <span>Requested by</span><strong>{task.requested_by || '-'}</strong>
          <span>Approved by</span><strong>{task.approved_by || '-'}</strong>
          <span>Created</span><strong>{task.created_at || '-'}</strong>
          <span>Picked</span><strong>{task.picked_at || '-'}</strong>
          <span>Finished</span><strong>{task.finished_at || '-'}</strong>
          <span>Expires</span><strong>{task.expires_at || '-'}</strong>
          <span>Attempt</span><strong>{task.attempt || 1}/{task.max_attempts || 3}</strong>
          <span>Retry of</span><strong>{task.retry_of_task_id || '-'}</strong>
          <span>Group</span><strong>{task.task_group_id || '-'}</strong>
        </div>
        <div className="button-row">
          <button onClick={() => act('cancel')} disabled={!['queued', 'picked'].includes(task.status)}>Cancel</button>
          <button onClick={() => act('retry')} disabled={!['failed', 'expired', 'canceled'].includes(task.status)}>Retry</button>
          <button onClick={() => act('approve')}>Approve</button>
          <button onClick={() => act('reject')}>Reject</button>
          <button onClick={copyResult}>Copy result</button>
          <button className="disabled inline" disabled>Manual write tasks blocked</button>
        </div>
      </section>
      <section className="panel">
        <h3>Redacted Result</h3>
        <div className="split-grid">
          <div><h4>stdout</h4><pre>{task.result_stdout || '-'}</pre></div>
          <div><h4>stderr</h4><pre>{task.result_stderr || '-'}</pre></div>
        </div>
        {task.error && <><h4>error</h4><pre>{task.error}</pre></>}
      </section>
      <section className="panel">
        <h3>Timeline</h3>
        <List items={(state.timeline || []).map((item) => `${item.time} [${item.level}] ${item.action}: ${item.message}`)} empty="No timeline yet" />
      </section>
    </div>
  );
}

function Capabilities({ nodes }) {
  const [caps, setCaps] = useState({ commands: [], blocked_patterns: [], future: [], safety_levels: [], allowed_task_actions: [], task_support: '', loading: true, error: '' });
  useEffect(() => {
    let alive = true;
    getJSON('/api/v1/capabilities')
      .then((data) => alive && setCaps({ ...data, loading: false, error: '' }))
      .catch((err) => alive && setCaps((prev) => ({ ...prev, loading: false, error: err.message })));
    return () => { alive = false; };
  }, []);
  if (caps.loading) return <Empty text="Loading capabilities" />;
  if (caps.error) return <div className="banner">Capabilities failed: {caps.error}</div>;
  return (
    <div className="capabilities-page">
      <section className="panel">
        <h3>Controller CLI Capability Classes</h3>
        <Table headers={['Command', 'Class', 'Note']}>
          {(caps.commands || []).map((item) => (
            <tr key={`${item.command}-${item.class}`}>
              <td>{item.command}</td>
              <td><span className={`tag ${item.class}`}>{item.class}</span></td>
              <td>{item.note}</td>
            </tr>
          ))}
        </Table>
      </section>
      <section className="panel">
        <h3>Blocked Patterns</h3>
        <List items={caps.blocked_patterns || []} empty="No blocked patterns reported" />
      </section>
      <section className="panel">
        <h3>Readonly Task Support</h3>
        <p className="muted">{caps.task_support || 'No task support advertised'}</p>
        <List items={caps.allowed_task_actions || []} empty="No readonly task actions reported" />
      </section>
      <section className="panel">
        <h3>Node-reported Capabilities</h3>
        {nodes.length ? (
          <Table headers={['Node', 'lq', 'Core', 'status json', 'doctor json', 'forward list', 'ddns overview', 'tasks enabled', 'snapshot record', 'rollback record', 'write actions', 'task actions']}>
            {nodes.map((node) => {
              const c = node.capabilities || {};
              return (
                <tr key={node.node_id}>
                  <td>{node.node_name || node.node_id}</td>
                  <td>{String(Boolean(c.lq_available))}</td>
                  <td>{c.core_version || node.core_version || '-'}</td>
                  <td>{String(Boolean(c.supports_status_json))}</td>
                  <td>{String(Boolean(c.supports_doctor_json))}</td>
                  <td>{String(Boolean(c.supports_forward_list))}</td>
                  <td>{String(Boolean(c.supports_ddns_overview))}</td>
                  <td>{String(Boolean(c.enable_tasks))}</td>
                  <td>{String(Boolean(c.supports_snapshot_manual_record))}</td>
                  <td>{String(Boolean(c.supports_rollback_manual_record))}</td>
                  <td>{String(Boolean(c.write_actions_supported))}</td>
                  <td>{(c.allowed_task_actions || []).join(', ') || '-'}</td>
                </tr>
              );
            })}
          </Table>
        ) : <Empty text="No nodes reported yet" />}
      </section>
    </div>
  );
}

function ActionCatalog() {
  const [catalog, setCatalog] = useState({ version: '', actions: [], loading: true, error: '' });
  useEffect(() => {
    let alive = true;
    getJSON('/api/v1/action-catalog')
      .then((data) => alive && setCatalog({ ...data, loading: false, error: '' }))
      .catch((err) => alive && setCatalog((prev) => ({ ...prev, loading: false, error: err.message })));
    return () => { alive = false; };
  }, []);
  if (catalog.loading) return <Empty text="Loading action catalog" />;
  if (catalog.error) return <div className="banner">Action catalog failed: {catalog.error}</div>;
  return (
    <div className="action-catalog-page">
      <section className="panel">
        <h3>Action Catalog</h3>
        <p className="muted">3.0.0-alpha.1 enables metadata-only actions and fixed alpha apply actions. High-level future actions such as create_forward, switch_entry, and restart_relay stay disabled.</p>
        <Table headers={['Action', 'Category', 'Risk', 'Enabled', 'Node mutation', 'Agent required', 'Command dispatch', 'Operator token', 'Required gates', 'Snapshot', 'Rollback', 'Approval', 'Description']}>
          {(catalog.actions || []).map((action) => (
            <tr key={action.action}>
              <td>{action.action}</td>
              <td><span className={`tag ${action.category}`}>{action.category}</span></td>
              <td><span className={`tag ${action.risk_level}`}>{action.risk_level}</span></td>
              <td><span className={`tag ${action.enabled ? 'ready' : 'disabled'}`}>{action.enabled ? 'Enabled' : 'Disabled / Future'}</span></td>
              <td>{String(Boolean(action.node_mutation))}</td>
              <td>{String(Boolean(action.agent_required))}</td>
              <td>{String(Boolean(action.command_dispatch))}</td>
              <td>{String(Boolean(action.operator_token_required))}</td>
              <td>{(action.required_gates || []).join(', ') || '-'}</td>
              <td>{String(Boolean(action.snapshot_required))}</td>
              <td>{String(Boolean(action.rollback_required))}</td>
              <td>{String(Boolean(action.approval_required))}</td>
              <td>{action.description}</td>
            </tr>
          ))}
        </Table>
      </section>
    </div>
  );
}

function Metric({ label, value }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function Nodes({ nodes, onOpen }) {
  async function copyRejoin(node) {
    const q = new URLSearchParams({
      controller_url: window.location.origin,
      node_name: node.node_name || node.node_id || 'leikwan-node',
      role: node.role || 'unknown',
      enable_tasks: String(Boolean(node.capabilities?.enable_tasks ?? true)),
      enable_write_actions: String(Boolean(node.capabilities?.write_actions_supported)),
      method: 'curl',
      token_mode: getOperatorToken() ? 'full' : 'masked'
    }).toString();
    const data = await getJSON(`/api/v1/bootstrap/agent-install-command?${q}`);
    await navigator.clipboard.writeText(data.command || data.masked_command || '');
  }
  if (!nodes.length) return <Empty text="No nodes reported yet" />;
  return (
    <Table headers={['Name', 'Role', 'Public IP', 'Core', 'Agent', 'Tasks', 'Alpha write', 'Supported write actions', 'Status', 'Last seen', 'Join']}>
      {nodes.map((n) => (
        <tr key={n.node_id}>
          <td><button className="link-button" onClick={() => onOpen(n.node_id)}>{n.node_name || n.node_id}</button></td>
          <td>{n.role}</td>
          <td>{n.public_ip || '-'}</td>
          <td>{n.core_version || '-'}</td>
          <td>{n.agent_version || '-'}</td>
          <td>{String(Boolean(n.capabilities?.enable_tasks))}</td>
          <td>{String(Boolean(n.capabilities?.write_actions_supported))}</td>
          <td>{(n.capabilities?.supported_write_actions || []).join(', ') || '-'}</td>
          <td><span className={`tag ${n.status}`}>{n.status}</span></td>
          <td>{n.last_seen || '-'}</td>
          <td><button className="link-button" onClick={() => copyRejoin(n)}>Copy rejoin</button></td>
        </tr>
      ))}
    </Table>
  );
}

function NodeDetail({ nodeId, entries, forwards }) {
  const [detail, setDetail] = useState({ node: null, reports: [], events: [], raw: null, loading: true, error: '' });
  const [actionMessage, setActionMessage] = useState('');
  useEffect(() => {
    let alive = true;
    async function load() {
      try {
        const [node, reports, events, raw] = await Promise.all([
          getJSON(`/api/v1/nodes/${encodeURIComponent(nodeId)}`),
          getJSON(`/api/v1/nodes/${encodeURIComponent(nodeId)}/reports?limit=20`),
          getJSON(`/api/v1/nodes/${encodeURIComponent(nodeId)}/events?limit=20`),
          getJSON(`/api/v1/nodes/${encodeURIComponent(nodeId)}/raw`)
        ]);
        if (alive) setDetail({ node, reports, events, raw, loading: false, error: '' });
      } catch (err) {
        if (alive) setDetail((prev) => ({ ...prev, loading: false, error: err.message }));
      }
    }
    load();
    return () => { alive = false; };
  }, [nodeId]);
  if (detail.loading) return <Empty text="Loading node detail" />;
  if (detail.error) return <div className="banner">Node detail failed: {detail.error}</div>;
  const node = detail.node;
  const nodeEntries = entries.filter((e) => e.node_id === nodeId);
  const nodeForwards = forwards.filter((f) => f.node_id === nodeId);
  const doctor = objectOrEmpty(node.doctor);
  const warnings = arrayOrEmpty(doctor.warnings);
  const suggestions = arrayOrEmpty(doctor.suggestions);
  async function runNodeAction(path, body = {}) {
    try {
      const res = await apiFetch(`/api/v1/nodes/${encodeURIComponent(nodeId)}/${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      });
      if (!res.ok) throw new Error(errorMessage(res));
      const task = await res.json();
      setActionMessage(`Queued ${path}: task #${task.id}`);
    } catch (err) {
      setActionMessage(err.message);
    }
  }
  return (
    <div className="detail">
      <section className="panel">
        <h3>Basic Information</h3>
        <dl className="kv">
          <dt>Name</dt><dd>{node.node_name || node.node_id}</dd>
          <dt>Role</dt><dd>{node.role}</dd>
          <dt>Status</dt><dd><span className={`tag ${node.status}`}>{node.status}</span></dd>
          <dt>Public IP</dt><dd>{node.public_ip || '-'}</dd>
          <dt>LAN IP</dt><dd>{node.lan_ip || '-'}</dd>
          <dt>EasyTier IP</dt><dd>{node.easytier_ip || '-'}</dd>
          <dt>Core</dt><dd>{node.core_version || '-'}</dd>
          <dt>Agent</dt><dd>{node.agent_version || '-'}</dd>
          <dt>Last seen</dt><dd>{node.last_seen || '-'}</dd>
        </dl>
      </section>
      <section className="panel">
        <h3>Services</h3>
        <KeyValue data={node.services || {}} />
      </section>
      <section className="panel">
        <h3>Node Actions</h3>
        <p className="muted">These buttons create fixed Agent tasks only. Reboot requires explicit confirmation.</p>
        <div className="action-row">
          <button onClick={() => runNodeAction('restart-agent')}>Restart Agent</button>
          <button onClick={() => runNodeAction('restart-easytier')}>Restart EasyTier</button>
          <button className="danger" onClick={() => { if (window.confirm('Type OK to queue reboot?')) runNodeAction('reboot', { confirm: 'REBOOT' }); }}>Reboot Node</button>
        </div>
        {actionMessage && <div className="banner">{actionMessage}</div>}
      </section>
      <section className="panel">
        <h3>Doctor</h3>
        <p>Overall: {doctor.overall || '-'}</p>
        <List title="Warnings" items={warnings} />
        <List title="Suggestions" items={suggestions} />
      </section>
      <section className="panel">
        <h3>Recent Errors</h3>
        <List items={node.recent_errors || []} empty="No recent errors" />
      </section>
      <section>
        <h3>Entries</h3>
        <EntriesTable entries={nodeEntries} />
      </section>
      <section>
        <h3>Forwards</h3>
        <ForwardsTable forwards={nodeForwards} />
      </section>
      <section>
        <h3>Recent Reports</h3>
        <Reports reports={detail.reports.slice(0, 20)} />
      </section>
      <section>
        <h3>Node Events</h3>
        <Events events={detail.events.slice(0, 20)} />
      </section>
      <details className="raw">
        <summary>Redacted raw_json</summary>
        <pre>{JSON.stringify(detail.raw, null, 2)}</pre>
      </details>
    </div>
  );
}

function objectOrEmpty(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return value;
}

function arrayOrEmpty(value) {
  return Array.isArray(value) ? value : [];
}

function KeyValue({ data }) {
  const entries = Object.entries(data);
  if (!entries.length) return <Empty text="No service data reported yet" />;
  return (
    <dl className="kv">
      {entries.map(([key, value]) => (
        <React.Fragment key={key}>
          <dt>{key}</dt><dd>{String(value || '-')}</dd>
        </React.Fragment>
      ))}
    </dl>
  );
}

function List({ title, items, empty = 'None' }) {
  return (
    <div className="list-block">
      {title && <strong>{title}</strong>}
      {items.length ? <ul>{items.map((item, i) => <li key={`${item}-${i}`}>{String(item)}</li>)}</ul> : <p>{empty}</p>}
    </div>
  );
}

function Reports({ reports }) {
  if (!reports.length) return <Empty text="No reports yet" />;
  return (
    <Table headers={['Time', 'Status', 'Health', 'Interval', 'Errors']}>
      {reports.map((r) => (
        <tr key={r.id}>
          <td>{r.created_at}</td>
          <td><span className={`tag ${r.status}`}>{r.status}</span></td>
          <td>{r.health_score}</td>
          <td>{r.interval_seconds}s</td>
          <td>{(r.recent_errors || []).join('; ') || '-'}</td>
        </tr>
      ))}
    </Table>
  );
}

function Entries({ entries, nodes = [], profiles = [] }) {
  const entryNodes = nodes.filter((node) => node.status === 'online' && ['entry', 'mixed', 'unknown'].includes(node.role));
  const relayNodes = nodes.filter((node) => node.status === 'online' && ['relay', 'mixed', 'unknown'].includes(node.role));
  const [items, setItems] = useState(entries || []);
  const [form, setForm] = useState({
    network_id: profiles[0]?.id || '',
    entry_node_id: entryNodes[0]?.node_id || '',
    relay_node_id: relayNodes[0]?.node_id || '',
    listen_host: '0.0.0.0',
    listen_port_start: 10000,
    listen_port_end: 19999,
    protocols: 'both'
  });
  const [error, setError] = useState('');
  useEffect(() => setItems(entries || []), [entries]);
  useEffect(() => {
    setForm((prev) => ({
      ...prev,
      network_id: prev.network_id || profiles[0]?.id || '',
      entry_node_id: prev.entry_node_id || entryNodes[0]?.node_id || '',
      relay_node_id: prev.relay_node_id || relayNodes[0]?.node_id || ''
    }));
  }, [nodes, profiles]);
  async function refresh() {
    setItems(await getJSON('/api/v1/entries'));
  }
  async function create(e) {
    e.preventDefault();
    try {
      const res = await apiFetch('/api/v1/entries', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...form, network_id: Number(form.network_id), listen_port_start: Number(form.listen_port_start), listen_port_end: Number(form.listen_port_end) })
      });
      if (!res.ok) throw new Error(errorMessage(res));
      await refresh();
      setError('');
    } catch (err) {
      setError(err.message);
    }
  }
  async function apply(id) {
    try {
      const res = await apiFetch(`/api/v1/entries/${id}/apply`, { method: 'POST' });
      if (!res.ok) throw new Error(errorMessage(res));
      await refresh();
      setError('');
    } catch (err) {
      setError(err.message);
    }
  }
  if (nodes.length || profiles.length) {
    return (
      <div className="entries-page">
        {error && <div className="banner">Entry request failed: {error}</div>}
        <section className="panel">
          <h3>Create Entry</h3>
          <p className="muted">Entry apply queues EasyTier, entry port, firewall reload and verify tasks for entry and relay nodes. It does not switch public entries or restart relay.</p>
          <form className="form-grid" onSubmit={create}>
            <label>Network<select value={form.network_id} onChange={(e) => setForm((prev) => ({ ...prev, network_id: e.target.value }))}>
              <option value="">Select network</option>
              {profiles.map((profile) => <option key={profile.id} value={profile.id}>{profile.name}</option>)}
            </select></label>
            <label>Entry node<select value={form.entry_node_id} onChange={(e) => setForm((prev) => ({ ...prev, entry_node_id: e.target.value }))}>
              <option value="">Select entry node</option>
              {entryNodes.map((node) => <option key={node.node_id} value={node.node_id}>{node.node_name || node.node_id}</option>)}
            </select></label>
            <label>Relay node<select value={form.relay_node_id} onChange={(e) => setForm((prev) => ({ ...prev, relay_node_id: e.target.value }))}>
              <option value="">Select relay node</option>
              {relayNodes.map((node) => <option key={node.node_id} value={node.node_id}>{node.node_name || node.node_id}</option>)}
            </select></label>
            <label>Listen host<input value={form.listen_host} onChange={(e) => setForm((prev) => ({ ...prev, listen_host: e.target.value }))} /></label>
            <label>Port start<input type="number" value={form.listen_port_start} onChange={(e) => setForm((prev) => ({ ...prev, listen_port_start: e.target.value }))} /></label>
            <label>Port end<input type="number" value={form.listen_port_end} onChange={(e) => setForm((prev) => ({ ...prev, listen_port_end: e.target.value }))} /></label>
            <label>Protocol<select value={form.protocols} onChange={(e) => setForm((prev) => ({ ...prev, protocols: e.target.value }))}>
              {['tcp', 'udp', 'both'].map((p) => <option key={p} value={p}>{p}</option>)}
            </select></label>
            <button className="primary-action" disabled={!form.network_id || !form.entry_node_id || !form.relay_node_id} type="submit">Create entry</button>
          </form>
        </section>
        <section>
          <h3>Entries</h3>
          <EntriesTable entries={items} onApply={apply} />
        </section>
      </div>
    );
  }
  return <EntriesTable entries={entries} />;
}

function EntriesTable({ entries, onApply }) {
  if (!entries.length) return <Empty text="No entries reported yet" />;
  return (
    <Table headers={['ID', 'Network', 'Entry node', 'Relay node', 'Listen', 'Protocol', 'Status', 'Actions']}>
      {entries.map((e) => (
        <tr key={`${e.id || e.node_id}-${e.entry_node_id || e.name}-${e.listen_port_start || e.listen_port}`}>
          <td>{e.id || '-'}</td>
          <td>{e.network_id || '-'}</td>
          <td>{e.entry_node_id || e.node_id || '-'}</td>
          <td>{e.relay_node_id || '-'}</td>
          <td>{e.listen_port_start ? `${e.listen_host || '0.0.0.0'}:${e.listen_port_start}-${e.listen_port_end}` : (e.listen_port || '-')}</td>
          <td>{e.protocols || e.protocol}</td>
          <td>{e.status}</td>
          <td>{onApply && e.id ? <button className="primary-action" onClick={() => onApply(e.id)}>Apply entry</button> : '-'}</td>
        </tr>
      ))}
    </Table>
  );
}

function Forwards({ forwards, nodes = [], profiles = [], entries = [], pbrPolicies = [] }) {
  const relayNodes = nodes.filter((node) => node.status === 'online' && ['relay', 'mixed', 'unknown'].includes(node.role));
  const [items, setItems] = useState(forwards || []);
  const [form, setForm] = useState({
    network_id: profiles[0]?.id || '',
    entry_id: entries[0]?.id || '',
    relay_node_id: relayNodes[0]?.node_id || '',
    name: 'demo-forward',
    listen_port: 10001,
    target_host: '',
    target_port: 443,
    protocol: 'both',
    pbr_policy_id: ''
  });
  const [error, setError] = useState('');
  useEffect(() => setItems(forwards || []), [forwards]);
  useEffect(() => {
    setForm((prev) => ({
      ...prev,
      network_id: prev.network_id || profiles[0]?.id || '',
      entry_id: prev.entry_id || entries[0]?.id || '',
      relay_node_id: prev.relay_node_id || relayNodes[0]?.node_id || ''
    }));
  }, [nodes, profiles, entries]);
  async function refresh() {
    setItems(await getJSON('/api/v1/forwards'));
  }
  async function create(e) {
    e.preventDefault();
    try {
      const res = await apiFetch('/api/v1/forwards', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...form, network_id: Number(form.network_id), entry_id: Number(form.entry_id), listen_port: Number(form.listen_port), target_port: Number(form.target_port), pbr_policy_id: Number(form.pbr_policy_id || 0) })
      });
      if (!res.ok) throw new Error(errorMessage(res));
      await refresh();
      setError('');
    } catch (err) {
      setError(err.message);
    }
  }
  async function apply(id) {
    try {
      const res = await apiFetch(`/api/v1/forwards/${id}/apply`, { method: 'POST' });
      if (!res.ok) throw new Error(errorMessage(res));
      await refresh();
      setError('');
    } catch (err) {
      setError(err.message);
    }
  }
  if (nodes.length || profiles.length || entries.length) {
    return (
      <div className="forwards-page">
        {error && <div className="banner">Forward request failed: {error}</div>}
        <section className="panel">
          <h3>Create Forward</h3>
          <p className="muted">Target machines do not need Agent. Enter the service as target_host:target_port.</p>
          <form className="form-grid" onSubmit={create}>
            <label>Network<select value={form.network_id} onChange={(e) => setForm((prev) => ({ ...prev, network_id: e.target.value }))}>
              <option value="">Select network</option>
              {profiles.map((profile) => <option key={profile.id} value={profile.id}>{profile.name}</option>)}
            </select></label>
            <label>Entry<select value={form.entry_id} onChange={(e) => setForm((prev) => ({ ...prev, entry_id: e.target.value }))}>
              <option value="">Select entry</option>
              {entries.map((entry) => <option key={entry.id} value={entry.id}>#{entry.id} {entry.entry_node_id}</option>)}
            </select></label>
            <label>Relay node<select value={form.relay_node_id} onChange={(e) => setForm((prev) => ({ ...prev, relay_node_id: e.target.value }))}>
              <option value="">Select relay node</option>
              {relayNodes.map((node) => <option key={node.node_id} value={node.node_id}>{node.node_name || node.node_id}</option>)}
            </select></label>
            <label>Name<input value={form.name} onChange={(e) => setForm((prev) => ({ ...prev, name: e.target.value }))} /></label>
            <label>Listen port<input type="number" value={form.listen_port} onChange={(e) => setForm((prev) => ({ ...prev, listen_port: e.target.value }))} /></label>
            <label>Target host<input value={form.target_host} placeholder="10.0.0.8 or service.example.com" onChange={(e) => setForm((prev) => ({ ...prev, target_host: e.target.value }))} /></label>
            <label>Target port<input type="number" value={form.target_port} onChange={(e) => setForm((prev) => ({ ...prev, target_port: e.target.value }))} /></label>
            <label>Protocol<select value={form.protocol} onChange={(e) => setForm((prev) => ({ ...prev, protocol: e.target.value }))}>
              {['tcp', 'udp', 'both'].map((p) => <option key={p} value={p}>{p}</option>)}
            </select></label>
            <label>PBR policy<select value={form.pbr_policy_id} onChange={(e) => setForm((prev) => ({ ...prev, pbr_policy_id: e.target.value }))}>
              <option value="">None</option>
              {pbrPolicies.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            </select></label>
            <button className="primary-action" disabled={!form.network_id || !form.entry_id || !form.relay_node_id || !form.target_host} type="submit">Create forward</button>
          </form>
        </section>
        <section>
          <h3>Forwards</h3>
          <ForwardsTable forwards={items} onApply={apply} />
        </section>
      </div>
    );
  }
  return <ForwardsTable forwards={forwards} />;
}

function ForwardsTable({ forwards, onApply }) {
  if (!forwards.length) return <Empty text="No forwards reported yet" />;
  return (
    <Table headers={['ID', 'Network', 'Entry', 'Relay node', 'Name', 'Listen', 'Target', 'Protocol', 'Status', 'Actions']}>
      {forwards.map((f) => (
        <tr key={`${f.id || f.node_id}-${f.name}-${f.target_port}`}>
          <td>{f.id || '-'}</td>
          <td>{f.network_id || '-'}</td>
          <td>{f.entry_id || f.entry_name || '-'}</td>
          <td>{f.relay_node_id || f.node_id || '-'}</td>
          <td>{f.name}</td>
          <td>{f.listen_port || '-'}</td>
          <td>{f.target_host}:{f.target_port}</td>
          <td>{f.protocol || f.protocols}</td>
          <td>{f.status}</td>
          <td>{onApply && f.id ? <button className="primary-action" onClick={() => onApply(f.id)}>Apply forward</button> : '-'}</td>
        </tr>
      ))}
    </Table>
  );
}

function PBR({ policies = [], nodes = [] }) {
  const relayNodes = nodes.filter((node) => node.status === 'online' && ['relay', 'mixed', 'unknown'].includes(node.role));
  const [items, setItems] = useState(policies || []);
  const [form, setForm] = useState({ name: 'pbr-demo', relay_node_id: relayNodes[0]?.node_id || '', source_cidr: '0.0.0.0/0', target_cidr: '0.0.0.0/0', output_interface: '', gateway: '', table_id: 100, priority: 1000, mark: '' });
  const [error, setError] = useState('');
  useEffect(() => setItems(policies || []), [policies]);
  useEffect(() => setForm((prev) => ({ ...prev, relay_node_id: prev.relay_node_id || relayNodes[0]?.node_id || '' })), [nodes]);
  async function refresh() { setItems(await getJSON('/api/v1/pbr-policies')); }
  async function create(e) {
    e.preventDefault();
    try {
      const res = await apiFetch('/api/v1/pbr-policies', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ...form, table_id: Number(form.table_id), priority: Number(form.priority) }) });
      if (!res.ok) throw new Error(errorMessage(res));
      await refresh();
      setError('');
    } catch (err) { setError(err.message); }
  }
  async function apply(id) {
    try {
      const res = await apiFetch(`/api/v1/pbr-policies/${id}/apply`, { method: 'POST' });
      if (!res.ok) throw new Error(errorMessage(res));
      setError('PBR apply task queued');
    } catch (err) { setError(err.message); }
  }
  return (
    <div>
      {error && <div className="banner">{error}</div>}
      <section className="panel">
        <h3>Create PBR Policy</h3>
        <form className="form-grid" onSubmit={create}>
          <label>Name<input value={form.name} onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))} /></label>
          <label>Relay node<select value={form.relay_node_id} onChange={(e) => setForm((p) => ({ ...p, relay_node_id: e.target.value }))}><option value="">Select relay</option>{relayNodes.map((n) => <option key={n.node_id} value={n.node_id}>{n.node_name || n.node_id}</option>)}</select></label>
          <label>Source CIDR<input value={form.source_cidr} onChange={(e) => setForm((p) => ({ ...p, source_cidr: e.target.value }))} /></label>
          <label>Target CIDR<input value={form.target_cidr} onChange={(e) => setForm((p) => ({ ...p, target_cidr: e.target.value }))} /></label>
          <label>Output interface<input value={form.output_interface} onChange={(e) => setForm((p) => ({ ...p, output_interface: e.target.value }))} /></label>
          <label>Gateway<input value={form.gateway} onChange={(e) => setForm((p) => ({ ...p, gateway: e.target.value }))} /></label>
          <label>Table ID<input type="number" value={form.table_id} onChange={(e) => setForm((p) => ({ ...p, table_id: e.target.value }))} /></label>
          <label>Priority<input type="number" value={form.priority} onChange={(e) => setForm((p) => ({ ...p, priority: e.target.value }))} /></label>
          <button className="primary-action" type="submit" disabled={!form.relay_node_id}>Create PBR</button>
        </form>
      </section>
      <Table headers={['ID', 'Name', 'Relay', 'Source', 'Target', 'Table', 'Priority', 'Status', 'Actions']}>
        {items.map((p) => <tr key={p.id}><td>{p.id}</td><td>{p.name}</td><td>{p.relay_node_id}</td><td>{p.source_cidr}</td><td>{p.target_cidr}</td><td>{p.table_id}</td><td>{p.priority}</td><td>{p.status}</td><td><button onClick={() => apply(p.id)}>Apply</button></td></tr>)}
      </Table>
    </div>
  );
}

function DDNS({ profiles = [], nodes = [] }) {
  const [items, setItems] = useState(profiles || []);
  const [form, setForm] = useState({ node_id: nodes[0]?.node_id || '', provider: 'manual', domain: '', record_type: 'A', api_token: '', zone_id: '', record_id: '', target: '', interval_seconds: 300 });
  const [error, setError] = useState('');
  useEffect(() => setItems(profiles || []), [profiles]);
  useEffect(() => setForm((prev) => ({ ...prev, node_id: prev.node_id || nodes[0]?.node_id || '' })), [nodes]);
  async function refresh() { setItems(await getJSON('/api/v1/ddns-profiles')); }
  async function create(e) {
    e.preventDefault();
    try {
      const res = await apiFetch('/api/v1/ddns-profiles', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ...form, interval_seconds: Number(form.interval_seconds) }) });
      if (!res.ok) throw new Error(errorMessage(res));
      await refresh();
      setError('');
    } catch (err) { setError(err.message); }
  }
  async function post(id, op) {
    try {
      const res = await apiFetch(`/api/v1/ddns-profiles/${id}/${op}`, { method: 'POST' });
      if (!res.ok) throw new Error(errorMessage(res));
      setError(`DDNS ${op} task queued`);
    } catch (err) { setError(err.message); }
  }
  return (
    <div>
      {error && <div className="banner">{error}</div>}
      <section className="panel">
        <h3>Create DDNS Profile</h3>
        <p className="muted">Tokens are accepted only in the create/update request and are redacted in API responses.</p>
        <form className="form-grid" onSubmit={create}>
          <label>Node<select value={form.node_id} onChange={(e) => setForm((p) => ({ ...p, node_id: e.target.value }))}><option value="">Select node</option>{nodes.map((n) => <option key={n.node_id} value={n.node_id}>{n.node_name || n.node_id}</option>)}</select></label>
          <label>Provider<select value={form.provider} onChange={(e) => setForm((p) => ({ ...p, provider: e.target.value }))}>{['manual', 'generic_webhook', 'cloudflare'].map((p) => <option key={p} value={p}>{p}</option>)}</select></label>
          <label>Domain<input value={form.domain} onChange={(e) => setForm((p) => ({ ...p, domain: e.target.value }))} /></label>
          <label>Record type<select value={form.record_type} onChange={(e) => setForm((p) => ({ ...p, record_type: e.target.value }))}>{['A', 'AAAA'].map((p) => <option key={p} value={p}>{p}</option>)}</select></label>
          <label>API token<input type="password" value={form.api_token} onChange={(e) => setForm((p) => ({ ...p, api_token: e.target.value }))} /></label>
          <label>Zone ID<input value={form.zone_id} onChange={(e) => setForm((p) => ({ ...p, zone_id: e.target.value }))} /></label>
          <label>Record ID<input value={form.record_id} onChange={(e) => setForm((p) => ({ ...p, record_id: e.target.value }))} /></label>
          <label>Webhook target<input value={form.target} onChange={(e) => setForm((p) => ({ ...p, target: e.target.value }))} /></label>
          <button className="primary-action" type="submit" disabled={!form.node_id || !form.domain}>Create DDNS</button>
        </form>
      </section>
      <Table headers={['ID', 'Node', 'Provider', 'Domain', 'Type', 'Status', 'Last sync', 'Actions']}>
        {items.map((d) => <tr key={d.id}><td>{d.id}</td><td>{d.node_id}</td><td>{d.provider}</td><td>{d.domain}</td><td>{d.record_type}</td><td>{d.status}</td><td>{d.last_sync_at || '-'}</td><td><button onClick={() => post(d.id, 'apply')}>Apply</button> <button onClick={() => post(d.id, 'sync')}>Sync now</button></td></tr>)}
      </Table>
    </div>
  );
}

function Events({ events, compact = false }) {
  if (!events.length) return <Empty text="No events yet" />;
  return (
    <Table headers={compact ? ['Level', 'Message', 'Time'] : ['Node', 'Level', 'Message', 'Time']}>
      {events.map((e) => (
        <tr key={e.id}>
          {!compact && <td>{e.node_id || '-'}</td>}
          <td><span className={`tag ${e.level}`}>{e.level}</span></td>
          <td>{e.message}</td>
          <td>{e.created_at}</td>
        </tr>
      ))}
    </Table>
  );
}

function Table({ headers, children }) {
  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>{headers.map((h) => <th key={h}>{h}</th>)}</tr>
        </thead>
        <tbody>{children}</tbody>
      </table>
    </div>
  );
}

function Empty({ text }) {
  return <div className="empty">{text}</div>;
}

createRoot(document.getElementById('root')).render(<App />);
