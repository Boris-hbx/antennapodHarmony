import { fileIo } from '@kit.CoreFileKit';

/**
 * 数据库导出/导入（#52）
 *
 * 导出：复制 DB 文件到 filesDir/backup/
 * 导入：验证 → 关闭当前 DB → 替换 → 提示重启
 */

const DB_NAME = 'AntennaPod.db';

/**
 * 导出数据库到沙箱备份目录
 * @returns 导出文件路径
 */
export async function exportDatabase(context: Context): Promise<string> {
  const dbPath = context.databaseDir + '/rdb/' + DB_NAME;

  // 验证源文件存在
  try {
    const stat = fileIo.statSync(dbPath);
    if (stat.size === 0) {
      throw new Error('数据库文件为空');
    }
  } catch (e) {
    throw new Error('数据库文件不存在或不可读');
  }

  // 创建备份目录
  const backupDir = context.filesDir + '/backup';
  try {
    fileIo.mkdirSync(backupDir, true);
  } catch (_e) { /* 已存在 */ }

  // 生成带日期的文件名
  const now = new Date();
  const dateStr = `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-${now.getDate().toString().padStart(2, '0')}`;
  const exportPath = `${backupDir}/AntennaPodBackup-${dateStr}.db`;

  // 复制
  try {
    fileIo.copyFileSync(dbPath, exportPath);
  } catch (e) {
    throw new Error('备份文件复制失败');
  }

  return exportPath;
}

/**
 * 导入数据库（从指定路径替换当前 DB）
 * 导入后需要重启应用才能生效
 */
export async function importDatabase(context: Context, sourcePath: string): Promise<void> {
  const dbDir = context.databaseDir + '/rdb';
  const dbPath = dbDir + '/' + DB_NAME;
  const tmpPath = dbDir + '/' + DB_NAME + '_import_tmp';

  // 复制源文件到临时路径
  try {
    fileIo.copyFileSync(sourcePath, tmpPath);
  } catch (e) {
    throw new Error('无法读取备份文件');
  }

  // 验证临时文件大小
  try {
    const stat = fileIo.statSync(tmpPath);
    if (stat.size < 1024) {
      fileIo.unlinkSync(tmpPath);
      throw new Error('备份文件太小，可能已损坏');
    }
  } catch (e) {
    const msg = (e instanceof Error) ? e.message : '';
    if (msg.includes('备份文件太小')) throw new Error(msg);
    try { fileIo.unlinkSync(tmpPath); } catch (_e) { /* ignore */ }
    throw new Error('备份文件验证失败');
  }

  // 替换当前 DB
  try {
    // 删除当前 DB
    try { fileIo.unlinkSync(dbPath); } catch (_e) { /* 可能不存在 */ }
    // WAL/SHM 文件也删除
    try { fileIo.unlinkSync(dbPath + '-wal'); } catch (_e) { /* ignore */ }
    try { fileIo.unlinkSync(dbPath + '-shm'); } catch (_e) { /* ignore */ }
    // 重命名临时文件为正式 DB
    fileIo.renameSync(tmpPath, dbPath);
  } catch (e) {
    // 清理
    try { fileIo.unlinkSync(tmpPath); } catch (_e) { /* ignore */ }
    throw new Error('数据库替换失败');
  }
}
