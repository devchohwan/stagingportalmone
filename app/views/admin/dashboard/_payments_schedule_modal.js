// 시간표 선택 모달 관련 함수들 (휴원 복귀용 - 월간 캘린더)

// 시간표 선택 모달 표시 (휴원 해제용)
window.showScheduleSelectModal = function(enrollmentId, teacher) {
  window.currentEnrollmentId = enrollmentId;

  window.scheduleModalData = {
    currentTeacher: teacher,
    teachers: window.TEACHERS_DATA,
    teacherHolidays: window.TEACHER_HOLIDAYS_DATA,
    selectedDate: null,
    currentMonth: new Date(),
    scheduleData: {}
  };

  renderTeacherTabs();
  loadScheduleForMonthAndRenderCalendar();

  document.getElementById('schedule-select-modal').style.display = 'flex';
};

// 선생님 탭 렌더링
function renderTeacherTabs() {
  const tabsContainer = document.getElementById('teacher-tabs');
  const teachers = window.scheduleModalData.teachers;
  const currentTeacher = window.scheduleModalData.currentTeacher;

  let html = '';
  teachers.forEach(teacher => {
    const isActive = teacher === currentTeacher;
    const style = isActive
      ? 'padding: 12px 24px; background: #667eea; color: white; border: none; border-bottom: 3px solid #667eea; cursor: pointer; font-weight: 600; font-size: 0.95rem;'
      : 'padding: 12px 24px; background: transparent; color: #6b7280; border: none; border-bottom: 3px solid transparent; cursor: pointer; font-weight: 500; font-size: 0.95rem;';

    html += `<button onclick="switchTeacher('${teacher}')" style="${style}">${teacher}</button>`;
  });

  tabsContainer.innerHTML = html;
}

// 선생님 전환
window.switchTeacher = function(teacher) {
  window.scheduleModalData.currentTeacher = teacher;
  window.scheduleModalData.selectedDate = null;

  renderTeacherTabs();
  document.getElementById('selected-date-info').style.display = 'none';
  document.getElementById('schedule-select-content').innerHTML = '<p style="text-align: center; color: #9ca3af;">날짜를 선택해주세요.</p>';

  loadScheduleForMonthAndRenderCalendar();
};

// 시간표 불러오고 캘린더 렌더링 (월간)
function loadScheduleForMonthAndRenderCalendar() {
  const teacher = window.scheduleModalData.currentTeacher;
  const currentMonth = window.scheduleModalData.currentMonth;
  const year = currentMonth.getFullYear();
  const month = currentMonth.getMonth() + 1;

  fetch(`/admin/load_monthly_schedule?teacher=${encodeURIComponent(teacher)}&year=${year}&month=${month}&mode=manager`)
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        window.scheduleModalData.scheduleData = data.schedules;
        renderMonthlyScheduleCalendar();
      } else {
        alert('시간표를 불러오는데 실패했습니다.');
      }
    })
    .catch(error => {
      console.log('Error:', error);
      alert('시간표를 불러오는데 실패했습니다.');
    });
}

// 캘린더 렌더링 (월간)
function renderMonthlyScheduleCalendar() {
  const currentMonth = window.scheduleModalData.currentMonth;
  const year = currentMonth.getFullYear();
  const month = currentMonth.getMonth();

  document.getElementById('schedule-calendar-month').textContent = `${year}년 ${month + 1}월`;

  const scheduleData = window.scheduleModalData.scheduleData;
  const teacherHolidays = window.scheduleModalData.teacherHolidays[window.scheduleModalData.currentTeacher] || [];
  const timeSlots = ['13-14', '14-15', '15-16', '16-17', '17-18', '19-20', '20-21', '21-22'];

  const firstDay = new Date(year, month, 1).getDay();
  const lastDate = new Date(year, month + 1, 0).getDate();
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  let html = '<table style="width: 100%; border-collapse: collapse;">';
  html += '<thead><tr>';
  ['일', '월', '화', '수', '목', '금', '토'].forEach(day => {
    html += `<th style="padding: 8px; text-align: center; font-weight: 600; color: #6b7280;">${day}</th>`;
  });
  html += '</tr></thead><tbody><tr>';

  for (let i = 0; i < firstDay; i++) {
    html += '<td style="padding: 20px; border: 1px solid #e5e7eb; background: #f9fafb;"></td>';
  }

  for (let date = 1; date <= lastDate; date++) {
    const currentDate = new Date(year, month, date);
    currentDate.setHours(0, 0, 0, 0);
    const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(date).padStart(2, '0')}`;

    const dayOfWeek = currentDate.getDay();
    const isHoliday = teacherHolidays.includes(dayOfWeek);
    const isPast = currentDate < today;

    let isFull = false;
    if (!isHoliday && scheduleData[dateStr]) {
      isFull = true;
      for (const timeSlot of timeSlots) {
        const students = scheduleData[dateStr][timeSlot] || [];
        if (students.length < 3) {
          isFull = false;
          break;
        }
      }
    }

    let style = 'height: 100px; padding: 15px; text-align: center; border: 1px solid #e5e7eb; vertical-align: top;';
    let bgColor = 'white';

    if (isPast) {
      bgColor = '#f3f4f6';
      style += ' cursor: not-allowed;';
    } else if (isHoliday) {
      bgColor = '#fef3c7';
      style += ' cursor: not-allowed;';
    } else if (isFull) {
      bgColor = '#fee2e2';
      style += ' cursor: not-allowed;';
    } else {
      bgColor = 'white';
      style += ' cursor: pointer;';
    }

    style += ` background: ${bgColor};`;

    const canSelect = !isPast && !isHoliday && !isFull;
    const onclick = canSelect ? `onclick="selectScheduleDate('${dateStr}')"` : '';
    const onmouseover = canSelect ? `onmouseover="this.style.background='#dbeafe'"` : '';
    const onmouseout = canSelect ? `onmouseout="this.style.background='${bgColor}'"` : '';

    html += `<td style="${style}" ${onclick} ${onmouseover} ${onmouseout}>`;
    html += `<div style="font-size: 1.1rem; font-weight: 600; margin-bottom: 5px;">${date}</div>`;

    if (isPast) {
      html += '<div style="font-size: 0.75rem; color: #9ca3af;">지난 날짜</div>';
    } else if (isHoliday) {
      html += '<div style="font-size: 0.75rem; color: #f59e0b;">휴무</div>';
    } else if (isFull) {
      html += '<div style="font-size: 0.75rem; color: #dc2626;">예약 불가</div>';
    }

    html += '</td>';

    if ((firstDay + date) % 7 === 0 && date !== lastDate) {
      html += '</tr><tr>';
    }
  }

  const lastDayOfWeek = (firstDay + lastDate) % 7;
  if (lastDayOfWeek !== 0) {
    for (let i = lastDayOfWeek; i < 7; i++) {
      html += '<td style="padding: 20px; border: 1px solid #e5e7eb; background: #f9fafb;"></td>';
    }
  }

  html += '</tr></tbody></table>';
  document.getElementById('schedule-calendar-content').innerHTML = html;
}

// 월 변경
window.changeScheduleMonth = function(delta) {
  window.scheduleModalData.currentMonth.setMonth(window.scheduleModalData.currentMonth.getMonth() + delta);
  window.scheduleModalData.selectedDate = null;
  document.getElementById('selected-date-info').style.display = 'none';
  document.getElementById('schedule-select-content').innerHTML = '<p style="text-align: center; color: #9ca3af;">날짜를 선택해주세요.</p>';
  loadScheduleForMonthAndRenderCalendar();
};

// 날짜 선택
window.selectScheduleDate = function(dateStr) {
  window.scheduleModalData.selectedDate = dateStr;

  const date = new Date(dateStr + 'T00:00:00');
  const dayOfWeek = date.getDay();
  const dayNames = ['일', '월', '화', '수', '목', '금', '토'];
  const dayKeys = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

  const selectedDay = dayKeys[dayOfWeek];

  const infoDiv = document.getElementById('selected-date-info');
  infoDiv.style.display = 'block';
  infoDiv.querySelector('p').textContent = `선택된 날짜: ${dateStr} (${dayNames[dayOfWeek]})`;

  const scheduleData = window.scheduleModalData.scheduleData;
  const teacherHolidays = window.scheduleModalData.teacherHolidays[window.scheduleModalData.currentTeacher] || [];
  const isHoliday = teacherHolidays.includes(dayOfWeek);

  renderScheduleForDate(dateStr, scheduleData[dateStr] || {}, isHoliday);
};

// 특정 날짜의 시간표 렌더링
function renderScheduleForDate(dateStr, dateSchedule, isHoliday) {
  const modalContent = document.getElementById('schedule-select-content');
  const timeSlots = ['13-14', '14-15', '15-16', '16-17', '17-18', '19-20', '20-21', '21-22'];

  const date = new Date(dateStr + 'T00:00:00');
  const dayOfWeek = date.getDay();
  const dayKeys = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  const day = dayKeys[dayOfWeek];

  let html = '<div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px;">';

  timeSlots.forEach(timeSlot => {
    const students = dateSchedule[timeSlot] || [];
    const currentCount = students.length;
    const isFull = currentCount >= 3;

    let cardStyle = 'padding: 20px; border-radius: 8px; text-align: center; border: 2px solid; transition: all 0.2s;';
    let onclick = '';

    if (isHoliday) {
      cardStyle += ' background: #fef3c7; color: #f59e0b; border-color: #fbbf24; cursor: not-allowed;';
    } else if (isFull) {
      cardStyle += ' background: #fee2e2; color: #dc2626; border-color: #fecaca; cursor: not-allowed;';
    } else {
      cardStyle += ' background: #dbeafe; color: #1e40af; border-color: #93c5fd; cursor: pointer;';
      onclick = `onclick="selectScheduleSlot('${day}', '${timeSlot}')"`;
    }

    html += `<div style="${cardStyle}" ${onclick}>`;
    html += `<div style="font-size: 1.1rem; font-weight: 600; margin-bottom: 8px;">${timeSlot.replace('-', ':00-')}:00</div>`;

    if (isHoliday) {
      html += '<div style="font-size: 0.9rem;">휴무</div>';
    } else {
      html += `<div style="font-size: 0.9rem;">${currentCount}/3</div>`;
      if (!isFull) {
        html += '<div style="font-size: 0.8rem; margin-top: 4px; color: #10b981;">선택 가능</div>';
      } else {
        html += '<div style="font-size: 0.8rem; margin-top: 4px;">자리 없음</div>';
      }
    }

    html += '</div>';
  });

  html += '</div>';
  modalContent.innerHTML = html;
}

// 시간대 선택
window.selectScheduleSlot = function(day, timeSlot) {
  const modalData = window.scheduleModalData;
  const selectedDate = modalData.selectedDate;
  const selectedTeacher = modalData.currentTeacher;

  if (!selectedDate) {
    alert('날짜를 먼저 선택해주세요.');
    return;
  }

  const dayNames = { sun: '일', mon: '월', tue: '화', wed: '수', thu: '목', fri: '금', sat: '토' };
  const confirmMessage = `${selectedTeacher} 선생님\n${selectedDate} (${dayNames[day]})\n${timeSlot.replace('-', ':00-')}:00\n\n위 시간대로 복귀하시겠습니까?`;

  if (!confirm(confirmMessage)) return;

  fetch(`/admin/user_enrollments/${window.currentEnrollmentId}/toggle_status`, {
    method: 'PATCH',
    headers: {
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      status: 'active',
      day: day,
      time_slot: timeSlot,
      teacher: selectedTeacher,
      first_lesson_date: selectedDate
    })
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      alert('복귀 처리되었습니다.');
      document.getElementById('schedule-select-modal').style.display = 'none';
      closeEnrollmentManageModal();
      window.loadPaymentsTab();
    } else {
      alert('복귀 처리 실패: ' + (data.error || '알 수 없는 오류'));
    }
  })
  .catch(error => {
    console.error('Error:', error);
    alert('복귀 처리 중 오류가 발생했습니다.');
  });
};

window.closeScheduleSelectModal = function() {
  document.getElementById('schedule-select-modal').style.display = 'none';
};
